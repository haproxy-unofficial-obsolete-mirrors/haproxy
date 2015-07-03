/*
 * Buffer management functions.
 *
 * Copyright 2000-2012 Willy Tarreau <w@1wt.eu>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *
 */

#include <ctype.h>
#include <stdio.h>
#include <string.h>

#include <common/config.h>
#include <common/buffer.h>
#include <common/memory.h>

#include <types/global.h>

struct pool_head *pool2_buffer;


/* perform minimal intializations, report 0 in case of error, 1 if OK. */
int init_buffer()
{
	pool2_buffer = create_pool("buffer", sizeof (struct buffer) + global.tune.bufsize, MEM_F_SHARED);
	return pool2_buffer != NULL;
}

/* This function writes the string <str> at position <pos> which must be in
 * buffer <b>, and moves <end> just after the end of <str>. <b>'s parameters
 * <l> and <r> are updated to be valid after the shift. The shift value
 * (positive or negative) is returned. If there's no space left, the move is
 * not done. The function does not adjust ->o because it does not make sense to
 * use it on data scheduled to be sent. For the same reason, it does not make
 * sense to call this function on unparsed data, so <orig> is not updated. The
 * string length is taken from parameter <len>. If <len> is null, the <str>
 * pointer is allowed to be null.
 */
int buffer_replace2(struct buffer *b, char *pos, char *end, const char *str, int len)
{
	int delta;

	delta = len - (end - pos);

	if (bi_end(b) + delta > b->data + b->size)
		return 0;  /* no space left */

	if (buffer_not_empty(b) &&
	    bi_end(b) + delta > bo_ptr(b) &&
	    bo_ptr(b) >= bi_end(b))
		return 0;  /* no space left before wrapping data */

	/* first, protect the end of the buffer */
	memmove(end + delta, end, bi_end(b) - end);

	/* now, copy str over pos */
	if (len)
		memcpy(pos, str, len);

	b->i += delta;

	if (buffer_empty(b))
		b->p = b->data;

	return delta;
}

/*
 * Inserts <str> followed by "\r\n" at position <pos> in buffer <b>. The <len>
 * argument informs about the length of string <str> so that we don't have to
 * measure it. It does not include the "\r\n". If <str> is NULL, then the buffer
 * is only opened for len+2 bytes but nothing is copied in. It may be useful in
 * some circumstances. The send limit is *not* adjusted. Same comments as above
 * for the valid use cases.
 *
 * The number of bytes added is returned on success. 0 is returned on failure.
 */
int buffer_insert_line2(struct buffer *b, char *pos, const char *str, int len)
{
	int delta;

	delta = len + 2;

	if (bi_end(b) + delta >= b->data + b->size)
		return 0;  /* no space left */

	if (buffer_not_empty(b) &&
	    bi_end(b) + delta > bo_ptr(b) &&
	    bo_ptr(b) >= bi_end(b))
		return 0;  /* no space left before wrapping data */

	/* first, protect the end of the buffer */
	memmove(pos + delta, pos, bi_end(b) - pos);

	/* now, copy str over pos */
	if (len && str) {
		memcpy(pos, str, len);
		pos[len] = '\r';
		pos[len + 1] = '\n';
	}

	b->i += delta;
	return delta;
}

/* This function realigns input data in a possibly wrapping buffer so that it
 * becomes contiguous and starts at the beginning of the buffer area. The
 * function may only be used when the buffer's output is empty.
 */
void buffer_slow_realign(struct buffer *buf)
{
	/* two possible cases :
	 *   - the buffer is in one contiguous block, we move it in-place
	 *   - the buffer is in two blocks, we move it via the swap_buffer
	 */
	if (buf->i) {
		int block1 = buf->i;
		int block2 = 0;
		if (buf->p + buf->i > buf->data + buf->size) {
			/* non-contiguous block */
			block1 = buf->data + buf->size - buf->p;
			block2 = buf->p + buf->i - (buf->data + buf->size);
		}
		if (block2)
			memcpy(swap_buffer, buf->data, block2);
		memmove(buf->data, buf->p, block1);
		if (block2)
			memcpy(buf->data + block1, swap_buffer, block2);
	}

	buf->p = buf->data;
}


/* Realigns a possibly non-contiguous buffer by bouncing bytes from source to
 * destination. It does not use any intermediate buffer and does the move in
 * place, though it will be slower than a simple memmove() on contiguous data,
 * so it's desirable to use it only on non-contiguous buffers. No pointers are
 * changed, the caller is responsible for that.
 */
void buffer_bounce_realign(struct buffer *buf)
{
	int advance, to_move;
	char *from, *to;

	from = bo_ptr(buf);
	advance = buf->data + buf->size - from;
	if (!advance)
		return;

	to_move = buffer_len(buf);
	while (to_move) {
		char last, save;

		last = *from;
		to = from + advance;
		if (to >= buf->data + buf->size)
			to -= buf->size;

		while (1) {
			save = *to;
			*to  = last;
			last = save;
			to_move--;
			if (!to_move)
				break;

			/* check if we went back home after rotating a number of bytes */
			if (to == from)
				break;

			/* if we ended up in the empty area, let's walk to next place. The
			 * empty area is either between buf->r and from or before from or
			 * after buf->r.
			 */
			if (from > bi_end(buf)) {
				if (to >= bi_end(buf) && to < from)
					break;
			} else if (from < bi_end(buf)) {
				if (to < from || to >= bi_end(buf))
					break;
			}

			/* we have overwritten a byte of the original set, let's move it */
			to += advance;
			if (to >= buf->data + buf->size)
				to -= buf->size;
		}

		from++;
		if (from >= buf->data + buf->size)
			from -= buf->size;
	}
}


/*
 * Dumps part or all of a buffer.
 */
void buffer_dump(FILE *o, struct buffer *b, int from, int to)
{
	fprintf(o, "Dumping buffer %p\n", b);
	fprintf(o, "            data=%p o=%d i=%d p=%p\n"
                   "            relative:   p=0x%04x\n",
		b->data, b->o, b->i, b->p, (unsigned int)(b->p - b->data));

	fprintf(o, "Dumping contents from byte %d to byte %d\n", from, to);
	fprintf(o, "         0  1  2  3  4  5  6  7    8  9  a  b  c  d  e  f\n");
	/* dump hexa */
	while (from < to) {
		int i;

		fprintf(o, "  %04x: ", from);
		for (i = 0; ((from + i) < to) && (i < 16) ; i++) {
			fprintf(o, "%02x ", (unsigned char)b->data[from + i]);
			if (((from + i)  & 15) == 7)
				fprintf(o, "- ");
		}
		if (to - from < 16) {
			int j = 0;

			for (j = 0; j <  from + 16 - to; j++)
				fprintf(o, "   ");
			if (j > 8)
				fprintf(o, "  ");
		}
		fprintf(o, "  ");
		for (i = 0; (from + i < to) && (i < 16) ; i++) {
			fprintf(o, "%c", isprint((int)b->data[from + i]) ? b->data[from + i] : '.') ;
			if ((((from + i) & 15) == 15) && ((from + i) != to-1))
				fprintf(o, "\n");
		}
		from += i;
	}
	fprintf(o, "\n--\n");
	fflush(o);
}


/*
 * Local variables:
 *  c-indent-level: 8
 *  c-basic-offset: 8
 * End:
 */
