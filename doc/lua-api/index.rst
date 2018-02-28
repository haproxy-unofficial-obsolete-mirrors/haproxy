.. toctree::
   :maxdepth: 2


How Lua runs in HAProxy
=======================

HAProxy Lua running contexts
----------------------------

The Lua code executed in HAProxy can be processed in 2 main modes. The first one
is the **initialisation mode**, and the second is the **runtime mode**.

* In the **initialisation mode**, we can perform DNS solves, but we cannot
  perform socket I/O. In this initialisation mode, HAProxy still blocked during
  the execution of the Lua program.

* In the **runtime mode**, we cannot perform DNS solves, but we can use sockets.
  The execution of the Lua code is multiplexed with the requests processing, so
  the Lua code seems to be run in blocking, but it is not the case.

The Lua code is loaded in one or more files. These files contains main code and
functions. Lua have 6 execution context.

1. The Lua file **body context**. It is executed during the load of the Lua file
   in the HAProxy `[global]` section with the directive `lua-load`. It is
   executed in initialisation mode. This section is use for configuring Lua
   bindings in HAProxy.

2. The Lua **init context**. It is a Lua function executed just after the
   HAProxy configuration parsing. The execution is in initialisation mode. In
   this context the HAProxy environment are already initialized. It is useful to
   check configuration, or initializing socket connections or tasks. These
   functions are declared in the body context with the Lua function
   `core.register_init()`. The prototype of the function is a simple function
   without return value and without parameters, like this: `function fcn()`.

3. The Lua **task context**. It is a Lua function executed after the start
   of the HAProxy scheduler, and just after the declaration of the task with the
   Lua function `core.register_task()`. This context can be concurrent with the
   traffic processing. It is executed in runtime mode. The prototype of the
   function is a simple function without return value and without parameters,
   like this: `function fcn()`.

4. The **action context**. It is a Lua function conditionally executed. These
   actions are registered by the Lua directives "`core.register_action()`". The
   prototype of the Lua called function is a function with doesn't returns
   anything and that take an object of class TXN as entry. `function fcn(txn)`.

5. The **sample-fetch context**. This function takes a TXN object as entry
   argument and returns a string. These types of function cannot execute any
   blocking function. They are useful to aggregate some of original HAProxy
   sample-fetches and return the result. The prototype of the function is
   `function string fcn(txn)`. These functions can be registered with the Lua
   function `core.register_fetches()`. Each declared sample-fetch is prefixed by
   the string "lua.".

   **NOTE**: It is possible that this function cannot found the required data
   in the original HAProxy sample-fetches, in this case, it cannot return the
   result. This case is not yet supported

6. The **converter context**. It is a Lua function that takes a string as input
   and returns another string as output. These types of function are stateless,
   it cannot access to any context. They don't execute any blocking function.
   The call prototype is `function string fcn(string)`. This function can be
   registered with the Lua function `core.register_converters()`. Each declared
   converter is prefixed by the string "lua.".

HAProxy Lua Hello world
-----------------------

HAProxy configuration file (`hello_world.conf`):

::

    global
       lua-load hello_world.lua

    listen proxy
       bind 127.0.0.1:10001
       tcp-request inspect-delay 1s
       tcp-request content use-service lua.hello_world

HAProxy Lua file (`hello_world.lua`):

.. code-block:: lua

    core.register_service("hello_world", "tcp", function(applet)
       applet:send("hello world\n")
    end)

How to start HAProxy for testing this configuration:

::

    ./haproxy -f hello_world.conf

On other terminal, you can test with telnet:

::

    #:~ telnet 127.0.0.1 10001
    hello world

Core class
==========

.. js:class:: core

   The "core" class contains all the HAProxy core functions. These function are
   useful for the controlling the execution flow, registering hooks, manipulating
   global maps or ACL, ...

   "core" class is basically provided with HAProxy. No `require` line is
   required to uses these function.

   The "core" class is static, it is not possible to create a new object of this
   type.

.. js:attribute:: core.emerg

  :returns: integer

  This attribute is an integer, it contains the value of the loglevel "emergency" (0).

.. js:attribute:: core.alert

  :returns: integer

  This attribute is an integer, it contains the value of the loglevel "alert" (1).

.. js:attribute:: core.crit

  :returns: integer

  This attribute is an integer, it contains the value of the loglevel "critical" (2).

.. js:attribute:: core.err

  :returns: integer

  This attribute is an integer, it contains the value of the loglevel "error" (3).

.. js:attribute:: core.warning

  :returns: integer

  This attribute is an integer, it contains the value of the loglevel "warning" (4).

.. js:attribute:: core.notice

  :returns: integer

  This attribute is an integer, it contains the value of the loglevel "notice" (5).

.. js:attribute:: core.info

  :returns: integer

  This attribute is an integer, it contains the value of the loglevel "info" (6).

.. js:attribute:: core.debug

  :returns: integer

  This attribute is an integer, it contains the value of the loglevel "debug" (7).

.. js:function:: core.log(loglevel, msg)

  **context**: body, init, task, action, sample-fetch, converter

  This function sends a log. The log is sent, according with the HAProxy
  configuration file, on the default syslog server if it is configured and on
  the stderr if it is allowed.

  :param integer loglevel: Is the log level asociated with the message. It is a
    number between 0 and 7.
  :param string msg: The log content.
  :see: core.emerg, core.alert, core.crit, core.err, core.warning, core.notice,
    core.info, core.debug (log level definitions)
  :see: code.Debug
  :see: core.Info
  :see: core.Warning
  :see: core.Alert

.. js:function:: core.Debug(msg)

  **context**: body, init, task, action, sample-fetch, converter

  :param string msg: The log content.
  :see: log

  Does the same job than:

.. code-block:: lua

  function Debug(msg)
    core.log(core.debug, msg)
  end
..

.. js:function:: core.Info(msg)

  **context**: body, init, task, action, sample-fetch, converter

  :param string msg: The log content.
  :see: log

.. code-block:: lua

  function Info(msg)
    core.log(core.info, msg)
  end
..

.. js:function:: core.Warning(msg)

  **context**: body, init, task, action, sample-fetch, converter

  :param string msg: The log content.
  :see: log

.. code-block:: lua

  function Warning(msg)
    core.log(core.warning, msg)
  end
..

.. js:function:: core.Alert(msg)

  **context**: body, init, task, action, sample-fetch, converter

  :param string msg: The log content.
  :see: log

.. code-block:: lua

  function Alert(msg)
    core.log(core.alert, msg)
  end
..

.. js:function:: core.add_acl(filename, key)

  **context**: init, task, action, sample-fetch, converter

  Add the ACL *key* in the ACLs list referenced by the file *filename*.

  :param string filename: the filename that reference the ACL entries.
  :param string key: the key which will be added.

.. js:function:: core.del_acl(filename, key)

  **context**: init, task, action, sample-fetch, converter

  Delete the ACL entry referenced by the key *key* in the list of ACLs
  referenced by *filename*.

  :param string filename: the filename that reference the ACL entries.
  :param string key: the key which will be deleted.

.. js:function:: core.del_map(filename, key)

  **context**: init, task, action, sample-fetch, converter

  Delete the map entry indexed with the specified key in the list of maps
  referenced by his filename.

  :param string filename: the filename that reference the map entries.
  :param string key: the key which will be deleted.

.. js:function:: core.get_info()

  **context**: body, init, task, action, sample-fetch, converter

  Returns HAProxy core informations. We can found information like the uptime,
  the pid, memory pool usage, tasks number, ...

  These information are also returned by the management sockat via the command
  "show info". See the management socket documentation fpor more information
  about the content of these variables.

  :returns: an array of values.

.. js:function:: core.now()

  **context**: body, init, task, action

  This function returns the current time. The time returned is fixed by the
  HAProxy core and assures than the hour will be monotnic and that the system
  call 'gettimeofday' will not be called too. The time is refreshed between each
  Lua execution or resume, so two consecutive call to the function "now" will
  probably returns the same result.

  :returns: an array which contains two entries "sec" and "usec". "sec"
    contains the current at the epoch format, and "usec" contains the
    current microseconds.

.. js:function:: core.msleep(milliseconds)

  **context**: body, init, task, action

  The `core.msleep()` stops the Lua execution between specified milliseconds.

  :param integer milliseconds: the required milliseconds.

.. js:attribute:: core.proxies

  **context**: body, init, task, action, sample-fetch, converter

  proxies is an array containing the list of all proxies declared in the
  configuration file. Each entry of the proxies array is an object of type
  :ref:`proxy_class`

.. js:function:: core.register_action(name, actions, func)

  **context**: body

  Register a Lua function executed as action. All the registered action can be
  used in HAProxy with the prefix "lua.". An action gets a TXN object class as
  input.

  :param string name: is the name of the converter.
  :param table actions: is a table of string describing the HAProxy actions who
                        want to register to. The expected actions are 'tcp-req',
                        'tcp-res', 'http-req' or 'http-res'.
  :param function func: is the Lua function called to work as converter.

  The prototype of the Lua function used as argument is:

.. code-block:: lua

  function(txn)
..

  * **txn** (:ref:`txn_class`): this is a TXN object used for manipulating the
            current request or TCP stream.

  Here, an exemple of action registration. the action juste send an 'Hello world'
  in the logs.

.. code-block:: lua

  core.register_action("hello-world", { "tcp-req", "http-req" }, function(txn)
     txn:Info("Hello world")
  end)
..

  This example code is used in HAproxy configuration like this:

::

  frontend tcp_frt
    mode tcp
    tcp-request content lua.hello-world

  frontend http_frt
    mode http
    http-request lua.hello-world

.. js:function:: core.register_converters(name, func)

  **context**: body

  Register a Lua function executed as converter. All the registered converters
  can be used in HAProxy with the prefix "lua.". An converter get a string as
  input and return a string as output. The registered function can take up to 9
  values as parameter. All the value are strings.

  :param string name: is the name of the converter.
  :param function func: is the Lua function called to work as converter.

  The prototype of the Lua function used as argument is:

.. code-block:: lua

  function(str, [p1 [, p2 [, ... [, p5]]]])
..

  * **str** (*string*): this is the input value automatically converted in
    string.
  * **p1** .. **p5** (*string*): this is a list of string arguments declared in
    the haroxy configuration file. The number of arguments doesn't exceed 5.
    The order and the nature of these is conventionally choose by the
    developper.

.. js:function:: core.register_fetches(name, func)

  **context**: body

  Register a Lua function executed as sample fetch. All the registered sample
  fetchs can be used in HAProxy with the prefix "lua.". A Lua sample fetch
  return a string as output. The registered function can take up to 9 values as
  parameter. All the value are strings.

  :param string name: is the name of the converter.
  :param function func: is the Lua function called to work as sample fetch.

  The prototype of the Lua function used as argument is:

.. code-block:: lua

    string function(txn, [p1 [, p2 [, ... [, p5]]]])
..

  * **txn** (:ref:`txn_class`): this is the txn object associated with the current
    request.
  * **p1** .. **p5** (*string*): this is a list of string arguments declared in
    the haroxy configuration file. The number of arguments doesn't exceed 5.
    The order and the nature of these is conventionally choose by the
    developper.
  * **Returns**: A string containing some data, ot nil if the value cannot be
    returned now.

  lua example code:

.. code-block:: lua

    core.register_fetches("hello", function(txn)
        return "hello"
    end)
..

  HAProxy example configuration:

::

    frontend example
       http-request redirect location /%[lua.hello]

.. js:function:: core.register_service(name, mode, func)

  **context**: body

  Register a Lua function executed as a service. All the registered service can
  be used in HAProxy with the prefix "lua.". A service gets an object class as
  input according with the required mode.

  :param string name: is the name of the converter.
  :param string mode: is string describing the required mode. Only 'tcp' or
                      'http' are allowed.
  :param function func: is the Lua function called to work as converter.

  The prototype of the Lua function used as argument is:

.. code-block:: lua

  function(applet)
..

  * **applet** *applet*  will be a :ref:`applettcp_class` or a
    :ref:`applethttp_class`. It depends the type of registered applet. An applet
    registered with the 'http' value for the *mode* parameter will gets a
    :ref:`applethttp_class`. If the *mode* value is 'tcp', the applet will gets
    a :ref:`applettcp_class`.

  **warning**: Applets of type 'http' cannot be called from 'tcp-*'
  rulesets. Only the 'http-*' rulesets are authorized, this means
  that is not possible to call an HTTP applet from a proxy in tcp
  mode. Applets of type 'tcp' can be called from anywhre.

  Here, an exemple of service registration. the service just send an 'Hello world'
  as an http response.

.. code-block:: lua

  core.register_service("hello-world", "http", function(applet)
     local response = "Hello World !"
     applet:set_status(200)
     applet:add_header("content-length", string.len(response))
     applet:add_header("content-type", "text/plain")
     applet:start_response()
     applet:send(response)
  end)
..

  This example code is used in HAproxy configuration like this:

::

    frontend example
       http-request use-service lua.hello-world

.. js:function:: core.register_init(func)

  **context**: body

  Register a function executed after the configuration parsing. This is useful
  to check any parameters.

  :param function func: is the Lua function called to work as initializer.

  The prototype of the Lua function used as argument is:

.. code-block:: lua

    function()
..

  It takes no input, and no output is expected.

.. js:function:: core.register_task(func)

  **context**: body, init, task, action, sample-fetch, converter

  Register and start independent task. The task is started when the HAProxy
  main scheduler starts. For example this type of tasks can be executed to
  perform complex health checks.

  :param function func: is the Lua function called to work as initializer.

  The prototype of the Lua function used as argument is:

.. code-block:: lua

    function()
..

  It takes no input, and no output is expected.

.. js:function:: core.register_cli([path], usage, func)

  **context**: body

  Register and start independent task. The task is started when the HAProxy
  main scheduler starts. For example this type of tasks can be executed to
  perform complex health checks.

  :param array path: is the sequence of word for which the cli execute the Lua
    binding.
  :param string usage: is the usage message displayed in the help.
  :param function func: is the Lua function called to handle the CLI commands.

  The prototype of the Lua function used as argument is:

.. code-block:: lua

    function(AppletTCP, [arg1, [arg2, [...]]])
..

  I/O are managed with the :ref:`applettcp_class` object. Args are given as
  paramter. The args embbed the registred path. If the path is declared like
  this:

.. code-block:: lua

    core.register_cli({"show", "ssl", "stats"}, "Display SSL stats..", function(applet, arg1, arg2, arg3, arg4, arg5)
	 end)
..

  And we execute this in the prompt:

.. code-block:: text

    > prompt
    > show ssl stats all
..

  Then, arg1, arg2 and arg3 will contains respectivey "show", "ssl" and "stats".
  arg4 will contain "all". arg5 contains nil.

.. js:function:: core.set_nice(nice)

  **context**: task, action, sample-fetch, converter

  Change the nice of the current task or current session.

  :param integer nice: the nice value, it must be between -1024 and 1024.

.. js:function:: core.set_map(filename, key, value)

  **context**: init, task, action, sample-fetch, converter

  set the value *value* associated to the key *key* in the map referenced by
  *filename*.

  :param string filename: the Map reference
  :param string key: the key to set or replace
  :param string value: the associated value

.. js:function:: core.sleep(int seconds)

  **context**: body, init, task, action

  The `core.sleep()` functions stop the Lua execution between specified seconds.

  :param integer seconds: the required seconds.

.. js:function:: core.tcp()

  **context**: init, task, action

  This function returns a new object of a *socket* class.

  :returns: A :ref:`socket_class` object.

.. js:function:: core.concat()

  **context**: body, init, task, action, sample-fetch, converter

  This function retruns a new concat object.

  :returns: A :ref:`concat_class` object.

.. js:function:: core.done(data)

  **context**: body, init, task, action, sample-fetch, converter

  :param any data: Return some data for the caller. It is useful with
    sample-fetches and sample-converters.

  Immediately stops the current Lua execution and returns to the caller which
  may be a sample fetch, a converter or an action and returns the specified
  value (ignored for actions). It is used when the LUA process finishes its
  work and wants to give back the control to HAProxy without executing the
  remaining code. It can be seen as a multi-level "return".

.. js:function:: core.yield()

  **context**: task, action, sample-fetch, converter

  Give back the hand at the HAProxy scheduler. It is used when the LUA
  processing consumes a lot of processing time.

.. js:function:: core.parse_addr(address)

  **context**: body, init, task, action, sample-fetch, converter

  :param network: is a string describing an ipv4 or ipv6 address and optionally
    its network length, like this: "127.0.0.1/8" or "aaaa::1234/32".
  :returns: a userdata containing network or nil if an error occurs.

  Parse ipv4 or ipv6 adresses and its facultative associated network.

.. js:function:: core.match_addr(addr1, addr2)

  **context**: body, init, task, action, sample-fetch, converter

  :param addr1: is an address created with "core.parse_addr".
  :param addr2: is an address created with "core.parse_addr".
  :returns: boolean, true if the network of the addresses matche, else returns
    false.

  Match two networks. For example "127.0.0.1/32" matchs "127.0.0.0/8". The order
  of network is not important.

.. js:function:: core.tokenize(str, separators [, noblank])

  **context**: body, init, task, action, sample-fetch, converter

  This function is useful for tokenizing an entry, or splitting some messages.
  :param string str: The string which will be split.
  :param string separators: A string containing a list of separators.
  :param boolean noblank: Ignore empty entries.
  :returns: an array of string.

  For example:

.. code-block:: lua

	local array = core.tokenize("This function is useful, for tokenizing an entry.", "., ", true)
	print_r(array)
..

  Returns this array:

.. code-block:: text

	(table) table: 0x21c01e0 [
	    1: (string) "This"
	    2: (string) "function"
	    3: (string) "is"
	    4: (string) "useful"
	    5: (string) "for"
	    6: (string) "tokenizing"
	    7: (string) "an"
	    8: (string) "entry"
	]
..

.. _proxy_class:

Proxy class
============

.. js:class:: Proxy

  This class provides a way for manipulating proxy and retrieving information
  like statistics.

.. js:attribute:: Proxy.servers

  Contain an array with the attached servers. Each server entry is an object of
  type :ref:`server_class`.

.. js:attribute:: Proxy.listeners

  Contain an array with the attached listeners. Each listeners entry is an
  object of type :ref:`listener_class`.

.. js:function:: Proxy.pause(px)

  Pause the proxy. See the management socket documentation for more information.

  :param class_proxy px: A :ref:`proxy_class` which indicates the manipulated
    proxy.

.. js:function:: Proxy.resume(px)

  Resume the proxy. See the management socket documentation for more
  information.

  :param class_proxy px: A :ref:`proxy_class` which indicates the manipulated
    proxy.

.. js:function:: Proxy.stop(px)

  Stop the proxy. See the management socket documentation for more information.

  :param class_proxy px: A :ref:`proxy_class` which indicates the manipulated
    proxy.

.. js:function:: Proxy.shut_bcksess(px)

  Kill the session attached to a backup server. See the management socket
  documentation for more information.

  :param class_proxy px: A :ref:`proxy_class` which indicates the manipulated
    proxy.

.. js:function:: Proxy.get_cap(px)

  Returns a string describing the capabilities of the proxy.

  :param class_proxy px: A :ref:`proxy_class` which indicates the manipulated
    proxy.
  :returns: a string "frontend", "backend", "proxy" or "ruleset".

.. js:function:: Proxy.get_mode(px)

  Returns a string describing the mode of the current proxy.

  :param class_proxy px: A :ref:`proxy_class` which indicates the manipulated
    proxy.
  :returns: a string "tcp", "http", "health" or "unknown"

.. js:function:: Proxy.get_stats(px)

  Returns an array containg the proxy statistics. The statistics returned are
  not the same if the proxy is frontend or a backend.

  :param class_proxy px: A :ref:`proxy_class` which indicates the manipulated
    proxy.
  :returns: a key/value array containing stats

.. _server_class:

Server class
============

.. js:function:: Server.is_draining(sv)

  Return true if the server is currently draining stiky connections.

  :param class_server sv: A :ref:`server_class` which indicates the manipulated
    server.
  :returns: a boolean

.. js:function:: Server.set_weight(sv, weight)

  Dynamically change the weight of the serveur. See the management socket
  documentation for more information about the format of the string.

  :param class_server sv: A :ref:`server_class` which indicates the manipulated
    server.
  :param string weight: A string describing the server weight.

.. js:function:: Server.get_weight(sv)

  This function returns an integer representing the serveur weight.

  :param class_server sv: A :ref:`server_class` which indicates the manipulated
    server.
  :returns: an integer.

.. js:function:: Server.set_addr(sv, addr)

  Dynamically change the address of the serveur. See the management socket
  documentation for more information about the format of the string.

  :param class_server sv: A :ref:`server_class` which indicates the manipulated
    server.
  :param string weight: A string describing the server address.

.. js:function:: Server.get_addr(sv)

  Returns a string describing the address of the serveur.

  :param class_server sv: A :ref:`server_class` which indicates the manipulated
    server.
  :returns: A string

.. js:function:: Server.get_stats(sv)

  Returns server statistics.

  :param class_server sv: A :ref:`server_class` which indicates the manipulated
    server.
  :returns: a key/value array containing stats

.. js:function:: Server.shut_sess(sv)

  Shutdown all the sessions attached to the server. See the management socket
  documentation for more information about this function.

  :param class_server sv: A :ref:`server_class` which indicates the manipulated
    server.

.. js:function:: Server.set_drain(sv)

  Drain sticky sessions. See the management socket documentation for more
  information about this function.

  :param class_server sv: A :ref:`server_class` which indicates the manipulated
    server.

.. js:function:: Server.set_maint(sv)

  Set maintenance mode. See the management socket documentation for more
  information about this function.

  :param class_server sv: A :ref:`server_class` which indicates the manipulated
    server.

.. js:function:: Server.set_ready(sv)

  Set normal mode. See the management socket documentation for more information
  about this function.

  :param class_server sv: A :ref:`server_class` which indicates the manipulated
    server.

.. js:function:: Server.check_enable(sv)

  Enable health checks. See the management socket documentation for more
  information about this function.

  :param class_server sv: A :ref:`server_class` which indicates the manipulated
    server.

.. js:function:: Server.check_disable(sv)

  Disable health checks. See the management socket documentation for more
  information about this function.

  :param class_server sv: A :ref:`server_class` which indicates the manipulated
    server.

.. js:function:: Server.check_force_up(sv)

  Force health-check up. See the management socket documentation for more
  information about this function.

  :param class_server sv: A :ref:`server_class` which indicates the manipulated
    server.

.. js:function:: Server.check_force_nolb(sv)

  Force health-check nolb mode. See the management socket documentation for more
  information about this function.

  :param class_server sv: A :ref:`server_class` which indicates the manipulated
    server.

.. js:function:: Server.check_force_down(sv)

  Force health-check down. See the management socket documentation for more
  information about this function.

  :param class_server sv: A :ref:`server_class` which indicates the manipulated
    server.

.. js:function:: Server.agent_enable(sv)

  Enable agent check. See the management socket documentation for more
  information about this function.

  :param class_server sv: A :ref:`server_class` which indicates the manipulated
    server.

.. js:function:: Server.agent_disable(sv)

  Disable agent check. See the management socket documentation for more
  information about this function.

  :param class_server sv: A :ref:`server_class` which indicates the manipulated
    server.

.. js:function:: Server.agent_force_up(sv)

  Force agent check up. See the management socket documentation for more
  information about this function.

  :param class_server sv: A :ref:`server_class` which indicates the manipulated
    server.

.. js:function:: Server.agent_force_down(sv)

  Force agent check down. See the management socket documentation for more
  information about this function.

  :param class_server sv: A :ref:`server_class` which indicates the manipulated
    server.

.. _listener_class:

Listener class
==============

.. js:function:: Listener.get_stats(ls)

  Returns server statistics.

  :param class_listener ls: A :ref:`listener_class` which indicates the
    manipulated listener.
  :returns: a key/value array containing stats

.. _concat_class:

Concat class
============

.. js:class:: Concat

  This class provides a fast way for string concatenation. The way using native
  Lua concatenation like the code below is slow for some reasons.

.. code-block:: lua

  str = "string1"
  str = str .. ", string2"
  str = str .. ", string3"
..

  For each concatenation, Lua:
  * allocate memory for the result,
  * catenate the two string copying the strings in the new memory bloc,
  * free the old memory block containing the string whoch is no longer used.
  This process does many memory move, allocation and free. In addition, the
  memory is not really freed, it is just mark mark as unsused and wait for the
  garbage collector.

  The Concat class provide an alternative way for catenating strings. It uses
  the internal Lua mechanism (it does not allocate memory), but it doesn't copy
  the data more than once.

  On my computer, the following loops spends 0.2s for the Concat method and
  18.5s for the pure Lua implementation. So, the Concat class is about 1000x
  faster than the embedded solution.

.. code-block:: lua

  for j = 1, 100 do
    c = core.concat()
    for i = 1, 20000 do
      c:add("#####")
    end
  end
..

.. code-block:: lua

  for j = 1, 100 do
    c = ""
    for i = 1, 20000 do
      c = c .. "#####"
    end
  end
..

.. js:function:: Concat.add(concat, string)

  This function adds a string to the current concatenated string.

  :param class_concat concat: A :ref:`concat_class` which contains the currently
    builded string.
  :param string string: A new string to concatenate to the current builded
    string.

.. js:function:: Concat.dump(concat)

  This function returns the concanated string.

  :param class_concat concat: A :ref:`concat_class` which contains the currently
    builded string.
  :returns: the concatenated string

.. _fetches_class:

Fetches class
=============

.. js:class:: Fetches

  This class contains a lot of internal HAProxy sample fetches. See the
  HAProxy "configuration.txt" documentation for more information about her
  usage. they are the chapters 7.3.2 to 7.3.6.

  **warning** some sample fetches are not available in some context. These
  limitations are specified in this documentation when theire useful.

  :see: TXN.f
  :see: TXN.sf

  Fetches are useful for:

  * get system time,
  * get environment variable,
  * get random numbers,
  * known backend status like the number of users in queue or the number of
    connections established,
  * client information like ip source or destination,
  * deal with stick tables,
  * Established SSL informations,
  * HTTP information like headers or method.

.. code-block:: lua

  function action(txn)
    -- Get source IP
    local clientip = txn.f:src()
  end
..

.. _converters_class:

Converters class
================

.. js:class:: Converters

  This class contains a lot of internal HAProxy sample converters. See the
  HAProxy documentation "configuration.txt" for more information about her
  usage. Its the chapter 7.3.1.

  :see: TXN.c
  :see: TXN.sc

  Converters provides statefull transformation. They are useful for:

  * converting input to base64,
  * applying hash on input string (djb2, crc32, sdbm, wt6),
  * format date,
  * json escape,
  * extracting preferred language comparing two lists,
  * turn to lower or upper chars,
  * deal with stick tables.

.. _channel_class:

Channel class
=============

.. js:class:: Channel

  HAProxy uses two buffers for the processing of the requests. The first one is
  used with the request data (from the client to the server) and the second is
  used for the response data (from the server to the client).

  Each buffer contains two types of data. The first type is the incoming data
  waiting for a processing. The second part is the outgoing data already
  processed. Usually, the incoming data is processed, after it is tagged as
  outgoing data, and finally it is sent. The following functions provides tools
  for manipulating these data in a buffer.

  The following diagram shows where the channel class function are applied.

  **Warning**: It is not possible to read from the response in request action,
  and it is not possible to read for the request channel in response action.

.. image:: _static/channel.png

.. js:function:: Channel.dup(channel)

  This function returns a string that contain the entire buffer. The data is
  not remove from the buffer and can be reprocessed later.

  If the buffer cant receive more data, a 'nil' value is returned.

  :param class_channel channel: The manipulated Channel.
  :returns: a string containing all the available data or nil.

.. js:function:: Channel.get(channel)

  This function returns a string that contain the entire buffer. The data is
  consumed from the buffer.

  If the buffer cant receive more data, a 'nil' value is returned.

  :param class_channel channel: The manipulated Channel.
  :returns: a string containing all the available data or nil.

.. js:function:: Channel.getline(channel)

  This function returns a string that contain the first line of the buffer. The
  data is consumed. If the data returned doesn't contains a final '\n' its
  assumed than its the last available data in the buffer.

  If the buffer cant receive more data, a 'nil' value is returned.

  :param class_channel channel: The manipulated Channel.
  :returns: a string containing the available line or nil.

.. js:function:: Channel.set(channel, string)

  This function replace the content of the buffer by the string. The function
  returns the copied length, otherwise, it returns -1.

  The data set with this function are not send. They wait for the end of
  HAProxy processing, so the buffer can be full.

  :param class_channel channel: The manipulated Channel.
  :param string string: The data which will sent.
  :returns: an integer containing the amount of bytes copied or -1.

.. js:function:: Channel.append(channel, string)

  This function append the string argument to the content of the buffer. The
  function returns the copied length, otherwise, it returns -1.

  The data set with this function are not send. They wait for the end of
  HAProxy processing, so the buffer can be full.

  :param class_channel channel: The manipulated Channel.
  :param string string: The data which will sent.
  :returns: an integer containing the amount of bytes copied or -1.

.. js:function:: Channel.send(channel, string)

  This function required immediate send of the data. Unless if the connection
  is close, the buffer is regularly flushed and all the string can be sent.

  :param class_channel channel: The manipulated Channel.
  :param string string: The data which will sent.
  :returns: an integer containing the amount of bytes copied or -1.

.. js:function:: Channel.get_in_length(channel)

  This function returns the length of the input part of the buffer.

  :param class_channel channel: The manipulated Channel.
  :returns: an integer containing the amount of available bytes.

.. js:function:: Channel.get_out_length(channel)

  This function returns the length of the output part of the buffer.

  :param class_channel channel: The manipulated Channel.
  :returns: an integer containing the amount of available bytes.

.. js:function:: Channel.forward(channel, int)

  This function transfer bytes from the input part of the buffer to the output
  part.

  :param class_channel channel: The manipulated Channel.
  :param integer int: The amount of data which will be forwarded.

.. js:function:: Channel.is_full(channel)

  This function returns true if the buffer channel is full.

  :returns: a boolean

.. _http_class:

HTTP class
==========

.. js:class:: HTTP

   This class contain all the HTTP manipulation functions.

.. js:function:: HTTP.req_get_headers(http)

  Returns an array containing all the request headers.

  :param class_http http: The related http object.
  :returns: array of headers.
  :see: HTTP.res_get_headers()

  This is the form of the returned array:

.. code-block:: lua

  HTTP:req_get_headers()['<header-name>'][<header-index>] = "<header-value>"

  local hdr = HTTP:req_get_headers()
  hdr["host"][0] = "www.test.com"
  hdr["accept"][0] = "audio/basic q=1"
  hdr["accept"][1] = "audio/*, q=0.2"
  hdr["accept"][2] = "*/*, q=0.1"
..

.. js:function:: HTTP.res_get_headers(http)

  Returns an array containing all the response headers.

  :param class_http http: The related http object.
  :returns: array of headers.
  :see: HTTP.req_get_headers()

  This is the form of the returned array:

.. code-block:: lua

  HTTP:res_get_headers()['<header-name>'][<header-index>] = "<header-value>"

  local hdr = HTTP:req_get_headers()
  hdr["host"][0] = "www.test.com"
  hdr["accept"][0] = "audio/basic q=1"
  hdr["accept"][1] = "audio/*, q=0.2"
  hdr["accept"][2] = "*.*, q=0.1"
..

.. js:function:: HTTP.req_add_header(http, name, value)

  Appends an HTTP header field in the request whose name is
  specified in "name" and whose value is defined in "value".

  :param class_http http: The related http object.
  :param string name: The header name.
  :param string value: The header value.
  :see: HTTP.res_add_header()

.. js:function:: HTTP.res_add_header(http, name, value)

  appends an HTTP header field in the response whose name is
  specified in "name" and whose value is defined in "value".

  :param class_http http: The related http object.
  :param string name: The header name.
  :param string value: The header value.
  :see: HTTP.req_add_header()

.. js:function:: HTTP.req_del_header(http, name)

  Removes all HTTP header fields in the request whose name is
  specified in "name".

  :param class_http http: The related http object.
  :param string name: The header name.
  :see: HTTP.res_del_header()

.. js:function:: HTTP.res_del_header(http, name)

  Removes all HTTP header fields in the response whose name is
  specified in "name".

  :param class_http http: The related http object.
  :param string name: The header name.
  :see: HTTP.req_del_header()

.. js:function:: HTTP.req_set_header(http, name, value)

  This variable replace all occurence of all header "name", by only
  one containing the "value".

  :param class_http http: The related http object.
  :param string name: The header name.
  :param string value: The header value.
  :see: HTTP.res_set_header()

  This function does the same work as the folowwing code:

.. code-block:: lua

   function fcn(txn)
      TXN.http:req_del_header("header")
      TXN.http:req_add_header("header", "value")
   end
..

.. js:function:: HTTP.res_set_header(http, name, value)

  This variable replace all occurence of all header "name", by only
  one containing the "value".

  :param class_http http: The related http object.
  :param string name: The header name.
  :param string value: The header value.
  :see: HTTP.req_rep_header()

.. js:function:: HTTP.req_rep_header(http, name, regex, replace)

  Matches the regular expression in all occurrences of header field "name"
  according to "regex", and replaces them with the "replace" argument. The
  replacement value can contain back references like \1, \2, ... This
  function works with the request.

  :param class_http http: The related http object.
  :param string name: The header name.
  :param string regex: The match regular expression.
  :param string replace: The replacement value.
  :see: HTTP.res_rep_header()

.. js:function:: HTTP.res_rep_header(http, name, regex, string)

  Matches the regular expression in all occurrences of header field "name"
  according to "regex", and replaces them with the "replace" argument. The
  replacement value can contain back references like \1, \2, ... This
  function works with the request.

  :param class_http http: The related http object.
  :param string name: The header name.
  :param string regex: The match regular expression.
  :param string replace: The replacement value.
  :see: HTTP.req_replace_header()

.. js:function:: HTTP.req_sub_header(http, name, regex, replace, options)

  Matches the regular expression in all occurrences of header field "name"
  according to "regex", and substitutes matches with the "replace" argument.
  The replacement value can contain back references like \1, \2, ... If the
  "options" argument contains "g" all matches are substituted - if empty 
  only only the first match in each header is substituted. This
  function works with the request.

  :param class_http http: The related http object.
  :param string name: The header name.
  :param string regex: The match regular expression.
  :param string replace: The replacement value.
  :param string options: Regex substitution options.
  :see: HTTP.res_sub_header()

.. js:function:: HTTP.res_sub_header(http, name, regex, string, options)

  Matches the regular expression in all occurrences of header field "name"
  according to "regex", and substitutes matches with the "replace" argument.
  The replacement value can contain back references like \1, \2, ... If the
  "options" argument contains "g" all matches are substituted - if empty 
  only only the first match in each header is substituted. This
  function works with the response.

  :param class_http http: The related http object.
  :param string name: The header name.
  :param string regex: The match regular expression.
  :param string replace: The replacement value.
  :param string options: Regex substitution options.
  :see: HTTP.req_sub_header()

.. js:function:: HTTP.req_set_method(http, method)

  Rewrites the request method with the parameter "method".

  :param class_http http: The related http object.
  :param string method: The new method.

.. js:function:: HTTP.req_set_path(http, path)

  Rewrites the request path with the "path" parameter.

  :param class_http http: The related http object.
  :param string path: The new path.

.. js:function:: HTTP.req_set_query(http, query)

  Rewrites the request's query string which appears after the first question
  mark ("?") with the parameter "query".

  :param class_http http: The related http object.
  :param string query: The new query.

.. js:function:: HTTP.req_set_uri(http, uri)

  Rewrites the request URI with the parameter "uri".

  :param class_http http: The related http object.
  :param string uri: The new uri.

.. js:function:: HTTP.res_set_status(http, status)

  Rewrites the response status code with the parameter "code". Note that the
  reason is automatically adapted to the new code.

  :param class_http http: The related http object.
  :param integer status: The new response status code.

.. _txn_class:

TXN class
=========

.. js:class:: TXN

  The txn class contain all the functions relative to the http or tcp
  transaction (Note than a tcp stream is the same than a tcp transaction, but
  an HTTP transaction is not the same than a tcp stream).

  The usage of this class permits to retrieve data from the requests, alter it
  and forward it.

  All the functions provided by this class are available in the context
  **sample-fetches** and **actions**.

.. js:attribute:: TXN.c

  :returns: An :ref:`converters_class`.

  This attribute contains a Converters class object.

.. js:attribute:: TXN.sc

  :returns: An :ref:`converters_class`.

  This attribute contains a Converters class object. The functions of
  this object returns always a string.

.. js:attribute:: TXN.f

  :returns: An :ref:`fetches_class`.

  This attribute contains a Fetches class object.

.. js:attribute:: TXN.sf

  :returns: An :ref:`fetches_class`.

  This attribute contains a Fetches class object. The functions of
  this object returns always a string.

.. js:attribute:: TXN.req

  :returns: An :ref:`channel_class`.

  This attribute contains a channel class object for the request buffer.

.. js:attribute:: TXN.res

  :returns: An :ref:`channel_class`.

  This attribute contains a channel class object for the response buffer.

.. js:attribute:: TXN.http

  :returns: An :ref:`http_class`.

  This attribute contains an HTTP class object. It is avalaible only if the
  proxy has the "mode http" enabled.

.. js:function:: TXN.log(TXN, loglevel, msg)

  This function sends a log. The log is sent, according with the HAProxy
  configuration file, on the default syslog server if it is configured and on
  the stderr if it is allowed.

  :param class_txn txn: The class txn object containing the data.
  :param integer loglevel: Is the log level asociated with the message. It is a
    number between 0 and 7.
  :param string msg: The log content.
  :see: core.emerg, core.alert, core.crit, core.err, core.warning, core.notice,
    core.info, core.debug (log level definitions)
  :see: TXN.deflog
  :see: TXN.Debug
  :see: TXN.Info
  :see: TXN.Warning
  :see: TXN.Alert

.. js:function:: TXN.deflog(TXN, msg)

  Sends a log line with the default loglevel for the proxy ssociated with the
  transaction.

  :param class_txn txn: The class txn object containing the data.
  :param string msg: The log content.
  :see: TXN.log

.. js:function:: TXN.Debug(txn, msg)

  :param class_txn txn: The class txn object containing the data.
  :param string msg: The log content.
  :see: TXN.log

  Does the same job than:

.. code-block:: lua

  function Debug(txn, msg)
    TXN.log(txn, core.debug, msg)
  end
..

.. js:function:: TXN.Info(txn, msg)

  :param class_txn txn: The class txn object containing the data.
  :param string msg: The log content.
  :see: TXN.log

.. code-block:: lua

  function Debug(txn, msg)
    TXN.log(txn, core.info, msg)
  end
..

.. js:function:: TXN.Warning(txn, msg)

  :param class_txn txn: The class txn object containing the data.
  :param string msg: The log content.
  :see: TXN.log

.. code-block:: lua

  function Debug(txn, msg)
    TXN.log(txn, core.warning, msg)
  end
..

.. js:function:: TXN.Alert(txn, msg)

  :param class_txn txn: The class txn object containing the data.
  :param string msg: The log content.
  :see: TXN.log

.. code-block:: lua

  function Debug(txn, msg)
    TXN.log(txn, core.alert, msg)
  end
..

.. js:function:: TXN.get_priv(txn)

  Return Lua data stored in the current transaction (with the `TXN.set_priv()`)
  function. If no data are stored, it returns a nil value.

  :param class_txn txn: The class txn object containing the data.
  :returns: the opaque data previsously stored, or nil if nothing is
     avalaible.

.. js:function:: TXN.set_priv(txn, data)

  Store any data in the current HAProxy transaction. This action replace the
  old stored data.

  :param class_txn txn: The class txn object containing the data.
  :param opaque data: The data which is stored in the transaction.

.. js:function:: TXN.set_var(TXN, var, value)

  Converts a Lua type in a HAProxy type and store it in a variable <var>.

  :param class_txn txn: The class txn object containing the data.
  :param string var: The variable name according with the HAProxy variable syntax.

.. js:function:: TXN.unset_var(TXN, var)

  Unset the variable <var>.

  :param class_txn txn: The class txn object containing the data.
  :param string var: The variable name according with the HAProxy variable syntax.

.. js:function:: TXN.get_var(TXN, var)

  Returns data stored in the variable <var> converter in Lua type.

  :param class_txn txn: The class txn object containing the data.
  :param string var: The variable name according with the HAProxy variable syntax.

.. js:function:: TXN.done(txn)

  This function terminates processing of the transaction and the associated
  session. It can be used when a critical error is detected or to terminate
  processing after some data have been returned to the client (eg: a redirect).

  *Warning*: It not make sense to call this function from sample-fetches. In
  this case the behaviour of this one is the same than core.done(): it quit
  the Lua execution. The transaction is really aborted only from an action
  registered function.

  :param class_txn txn: The class txn object containing the data.

.. js:function:: TXN.set_loglevel(txn, loglevel)

  Is used to change the log level of the current request. The "loglevel" must
  be an integer between 0 and 7.

  :param class_txn txn: The class txn object containing the data.
  :param integer loglevel: The required log level. This variable can be one of
  :see: core.<loglevel>

.. js:function:: TXN.set_tos(txn, tos)

  Is used to set the TOS or DSCP field value of packets sent to the client to
  the value passed in "tos" on platforms which support this.

  :param class_txn txn: The class txn object containing the data.
  :param integer tos: The new TOS os DSCP.

.. js:function:: TXN.set_mark(txn, mark)

  Is used to set the Netfilter MARK on all packets sent to the client to the
  value passed in "mark" on platforms which support it.

  :param class_txn txn: The class txn object containing the data.
  :param integer mark: The mark value.

.. _socket_class:

Socket class
============

.. js:class:: Socket

  This class must be compatible with the Lua Socket class. Only the 'client'
  functions are available. See the Lua Socket documentation:

  `http://w3.impa.br/~diego/software/luasocket/tcp.html
  <http://w3.impa.br/~diego/software/luasocket/tcp.html>`_

.. js:function:: Socket.close(socket)

  Closes a TCP object. The internal socket used by the object is closed and the
  local address to which the object was bound is made available to other
  applications. No further operations (except for further calls to the close
  method) are allowed on a closed Socket.

  :param class_socket socket: Is the manipulated Socket.

  Note: It is important to close all used sockets once they are not needed,
  since, in many systems, each socket uses a file descriptor, which are limited
  system resources. Garbage-collected objects are automatically closed before
  destruction, though.

.. js:function:: Socket.connect(socket, address[, port])

  Attempts to connect a socket object to a remote host.


  In case of error, the method returns nil followed by a string describing the
  error. In case of success, the method returns 1.

  :param class_socket socket: Is the manipulated Socket.
  :param string address: can be an IP address or a host name. See below for more
                         information.
  :param integer port: must be an integer number in the range [1..64K].
  :returns: 1 or nil.

  an address field extension permits to use the connect() function to connect to
  other stream than TCP. The syntax containing a simpleipv4 or ipv6 address is
  the basically expected format. This format requires the port.

  Other format accepted are a socket path like "/socket/path", it permits to
  connect to a socket. abstract namespaces are supported with the prefix
  "abns@", and finaly a filedescriotr can be passed with the prefix "fd@".
  The prefix "ipv4@", "ipv6@" and "unix@" are also supported. The port can be
  passed int the string. The syntax "127.0.0.1:1234" is valid. in this case, the
  parameter *port* is ignored.

.. js:function:: Socket.connect_ssl(socket, address, port)

  Same behavior than the function socket:connect, but uses SSL.

  :param class_socket socket: Is the manipulated Socket.
  :returns: 1 or nil.

.. js:function:: Socket.getpeername(socket)

  Returns information about the remote side of a connected client object.

  Returns a string with the IP address of the peer, followed by the port number
  that peer is using for the connection. In case of error, the method returns
  nil.

  :param class_socket socket: Is the manipulated Socket.
  :returns: a string containing the server information.

.. js:function:: Socket.getsockname(socket)

  Returns the local address information associated to the object.

  The method returns a string with local IP address and a number with the port.
  In case of error, the method returns nil.

  :param class_socket socket: Is the manipulated Socket.
  :returns: a string containing the client information.

.. js:function:: Socket.receive(socket, [pattern [, prefix]])

  Reads data from a client object, according to the specified read pattern.
  Patterns follow the Lua file I/O format, and the difference in performance
  between all patterns is negligible.

  :param class_socket socket: Is the manipulated Socket.
  :param string|integer pattern: Describe what is required (see below).
  :param string prefix: A string which will be prefix the returned data.
  :returns:  a string containing the required data or nil.

  Pattern can be any of the following:

  * **`*a`**: reads from the socket until the connection is closed. No
              end-of-line translation is performed;

  * **`*l`**: reads a line of text from the Socket. The line is terminated by a
              LF character (ASCII 10), optionally preceded by a CR character
              (ASCII 13). The CR and LF characters are not included in the
              returned line.  In fact, all CR characters are ignored by the
              pattern. This is the default pattern.

  * **number**: causes the method to read a specified number of bytes from the
                Socket. Prefix is an optional string to be concatenated to the
                beginning of any received data before return.

  * **empty**: If the pattern is left empty, the default option is `*l`.

  If successful, the method returns the received pattern. In case of error, the
  method returns nil followed by an error message which can be the string
  'closed' in case the connection was closed before the transmission was
  completed or the string 'timeout' in case there was a timeout during the
  operation. Also, after the error message, the function returns the partial
  result of the transmission.

  Important note: This function was changed severely. It used to support
  multiple patterns (but I have never seen this feature used) and now it
  doesn't anymore.  Partial results used to be returned in the same way as
  successful results. This last feature violated the idea that all functions
  should return nil on error.  Thus it was changed too.

.. js:function:: Socket.send(socket, data [, start [, end ]])

  Sends data through client object.

  :param class_socket socket: Is the manipulated Socket.
  :param string data: The data that will be sent.
  :param integer start: The start position in the buffer of the data which will
   be sent.
  :param integer end: The end position in the buffer of the data which will
   be sent.
  :returns: see below.

  Data is the string to be sent. The optional arguments i and j work exactly
  like the standard string.sub Lua function to allow the selection of a
  substring to be sent.

  If successful, the method returns the index of the last byte within [start,
  end] that has been sent. Notice that, if start is 1 or absent, this is
  effectively the total number of bytes sent. In case of error, the method
  returns nil, followed by an error message, followed by the index of the last
  byte within [start, end] that has been sent. You might want to try again from
  the byte following that. The error message can be 'closed' in case the
  connection was closed before the transmission was completed or the string
  'timeout' in case there was a timeout during the operation.

  Note: Output is not buffered. For small strings, it is always better to
  concatenate them in Lua (with the '..' operator) and send the result in one
  call instead of calling the method several times.

.. js:function:: Socket.setoption(socket, option [, value])

  Just implemented for compatibility, this cal does nothing.

.. js:function:: Socket.settimeout(socket, value [, mode])

  Changes the timeout values for the object. All I/O operations are blocking.
  That is, any call to the methods send, receive, and accept will block
  indefinitely, until the operation completes. The settimeout method defines a
  limit on the amount of time the I/O methods can block. When a timeout time
  has elapsed, the affected methods give up and fail with an error code.

  The amount of time to wait is specified as the value parameter, in seconds.

  The timeout modes are bot implemented, the only settable timeout is the
  inactivity time waiting for complete the internal buffer send or waiting for
  receive data.

  :param class_socket socket: Is the manipulated Socket.
  :param integer value: The timeout value.

.. _map_class:

Map class
=========

.. js:class:: Map

  This class permits to do some lookup in HAProxy maps. The declared maps can
  be modified during the runtime throught the HAProxy management socket.

.. code-block:: lua

  default = "usa"

  -- Create and load map
  geo = Map.new("geo.map", Map.ip);

  -- Create new fetch that returns the user country
  core.register_fetches("country", function(txn)
    local src;
    local loc;

    src = txn.f:fhdr("x-forwarded-for");
    if (src == nil) then
      src = txn.f:src()
      if (src == nil) then
        return default;
      end
    end

    -- Perform lookup
    loc = geo:lookup(src);

    if (loc == nil) then
      return default;
    end

    return loc;
  end);

.. js:attribute:: Map.int

  See the HAProxy configuration.txt file, chapter "Using ACLs and fetching
  samples" ans subchapter "ACL basics" to understand this pattern matching
  method.

.. js:attribute:: Map.ip

  See the HAProxy configuration.txt file, chapter "Using ACLs and fetching
  samples" ans subchapter "ACL basics" to understand this pattern matching
  method.

.. js:attribute:: Map.str

  See the HAProxy configuration.txt file, chapter "Using ACLs and fetching
  samples" ans subchapter "ACL basics" to understand this pattern matching
  method.

.. js:attribute:: Map.beg

  See the HAProxy configuration.txt file, chapter "Using ACLs and fetching
  samples" ans subchapter "ACL basics" to understand this pattern matching
  method.

.. js:attribute:: Map.sub

  See the HAProxy configuration.txt file, chapter "Using ACLs and fetching
  samples" ans subchapter "ACL basics" to understand this pattern matching
  method.

.. js:attribute:: Map.dir

  See the HAProxy configuration.txt file, chapter "Using ACLs and fetching
  samples" ans subchapter "ACL basics" to understand this pattern matching
  method.

.. js:attribute:: Map.dom

  See the HAProxy configuration.txt file, chapter "Using ACLs and fetching
  samples" ans subchapter "ACL basics" to understand this pattern matching
  method.

.. js:attribute:: Map.end

  See the HAProxy configuration.txt file, chapter "Using ACLs and fetching
  samples" ans subchapter "ACL basics" to understand this pattern matching
  method.

.. js:attribute:: Map.reg

  See the HAProxy configuration.txt file, chapter "Using ACLs and fetching
  samples" ans subchapter "ACL basics" to understand this pattern matching
  method.


.. js:function:: Map.new(file, method)

  Creates and load a map.

  :param string file: Is the file containing the map.
  :param integer method: Is the map pattern matching method. See the attributes
    of the Map class.
  :returns: a class Map object.
  :see: The Map attributes.

.. js:function:: Map.lookup(map, str)

  Perform a lookup in a map.

  :param class_map map: Is the class Map object.
  :param string str: Is the string used as key.
  :returns: a string containing the result or nil if no match.

.. js:function:: Map.slookup(map, str)

  Perform a lookup in a map.

  :param class_map map: Is the class Map object.
  :param string str: Is the string used as key.
  :returns: a string containing the result or empty string if no match.

.. _applethttp_class:

AppletHTTP class
================

.. js:class:: AppletHTTP

  This class is used with applets that requires the 'http' mode. The http applet
  can be registered with the *core.register_service()* function. They are used
  for processing an http request like a server in back of HAProxy.

  This is an hello world sample code:

.. code-block:: lua

  core.register_service("hello-world", "http", function(applet)
     local response = "Hello World !"
     applet:set_status(200)
     applet:add_header("content-length", string.len(response))
     applet:add_header("content-type", "text/plain")
     applet:start_response()
     applet:send(response)
  end)

.. js:attribute:: AppletHTTP.c

  :returns: A :ref:`converters_class`

  This attribute contains a Converters class object.

.. js:attribute:: AppletHTTP.sc

  :returns: A :ref:`converters_class`

  This attribute contains a Converters class object. The
  functions of this object returns always a string.

.. js:attribute:: AppletHTTP.f

  :returns: A :ref:`fetches_class`

  This attribute contains a Fetches class object. Note that the
  applet execution place cannot access to a valid HAProxy core HTTP
  transaction, so some sample fecthes related to the HTTP dependant
  values (hdr, path, ...) are not available.

.. js:attribute:: AppletHTTP.sf

  :returns: A :ref:`fetches_class`

  This attribute contains a Fetches class object. The functions of
  this object returns always a string. Note that the applet
  execution place cannot access to a valid HAProxy core HTTP
  transaction, so some sample fecthes related to the HTTP dependant
  values (hdr, path, ...) are not available.

.. js:attribute:: AppletHTTP.method

  :returns: string

  The attribute method returns a string containing the HTTP
  method.

.. js:attribute:: AppletHTTP.version

  :returns: string

  The attribute version, returns a string containing the HTTP
  request version.

.. js:attribute:: AppletHTTP.path

  :returns: string

  The attribute path returns a string containing the HTTP
  request path.

.. js:attribute:: AppletHTTP.qs

  :returns: string

  The attribute qs returns a string containing the HTTP
  request query string.

.. js:attribute:: AppletHTTP.length

  :returns: integer

  The attribute length returns an integer containing the HTTP
  body length.

.. js:attribute:: AppletHTTP.headers

  :returns: array

  The attribute headers returns an array containing the HTTP
  headers. The header names are always in lower case. As the header name can be
  encountered more than once in each request, the value is indexed with 0 as
  first index value. The array have this form:

.. code-block:: lua

  AppletHTTP.headers['<header-name>'][<header-index>] = "<header-value>"

  AppletHTTP.headers["host"][0] = "www.test.com"
  AppletHTTP.headers["accept"][0] = "audio/basic q=1"
  AppletHTTP.headers["accept"][1] = "audio/*, q=0.2"
  AppletHTTP.headers["accept"][2] = "*/*, q=0.1"
..

.. js:attribute:: AppletHTTP.headers

  Contains an array containing all the request headers.

.. js:function:: AppletHTTP.set_status(applet, code)

  This function sets the HTTP status code for the response. The allowed code are
  from 100 to 599.

  :param class_AppletHTTP applet: An :ref:`applethttp_class`
  :param integer code: the status code returned to the client.

.. js:function:: AppletHTTP.add_header(applet, name, value)

  This function add an header in the response. Duplicated headers are not
  collapsed. The special header *content-length* is used to determinate the
  response length. If it not exists, a *transfer-encoding: chunked* is set, and
  all the write from the funcion *AppletHTTP:send()* become a chunk.

  :param class_AppletHTTP applet: An :ref:`applethttp_class`
  :param string name: the header name
  :param string value: the header value

.. js:function:: AppletHTTP.start_response(applet)

  This function indicates to the HTTP engine that it can process and send the
  response headers. After this called we cannot add headers to the response; We
  cannot use the *AppletHTTP:send()* function if the
  *AppletHTTP:start_response()* is not called.

  :param class_AppletHTTP applet: An :ref:`applethttp_class`

.. js:function:: AppletHTTP.getline(applet)

  This function returns a string containing one line from the http body. If the
  data returned doesn't contains a final '\\n' its assumed than its the last
  available data before the end of stream.

  :param class_AppletHTTP applet: An :ref:`applethttp_class`
  :returns: a string. The string can be empty if we reach the end of the stream.

.. js:function:: AppletHTTP.receive(applet, [size])

  Reads data from the HTTP body, according to the specified read *size*. If the
  *size* is missing, the function tries to read all the content of the stream
  until the end. If the *size* is bigger than the http body, it returns the
  amount of data avalaible.

  :param class_AppletHTTP applet: An :ref:`applethttp_class`
  :param integer size: the required read size.
  :returns: always return a string,the string can be empty is the connexion is
            closed.

.. js:function:: AppletHTTP.send(applet, msg)

  Send the message *msg* on the http request body.

  :param class_AppletHTTP applet: An :ref:`applethttp_class`
  :param string msg: the message to send.

.. js:function:: AppletHTTP.get_priv(applet)

  Return Lua data stored in the current transaction (with the
  `AppletHTTP.set_priv()`) function. If no data are stored, it returns a nil
  value.

  :param class_AppletHTTP applet: An :ref:`applethttp_class`
  :returns: the opaque data previsously stored, or nil if nothing is
     avalaible.

.. js:function:: AppletHTTP.set_priv(applet, data)

  Store any data in the current HAProxy transaction. This action replace the
  old stored data.

  :param class_AppletHTTP applet: An :ref:`applethttp_class`
  :param opaque data: The data which is stored in the transaction.

.. _applettcp_class:

AppletTCP class
===============

.. js:class:: AppletTCP

  This class is used with applets that requires the 'tcp' mode. The tcp applet
  can be registered with the *core.register_service()* function. They are used
  for processing a tcp stream like a server in back of HAProxy.

.. js:attribute:: AppletTCP.c

  :returns: A :ref:`converters_class`

  This attribute contains a Converters class object.

.. js:attribute:: AppletTCP.sc

  :returns: A :ref:`converters_class`

  This attribute contains a Converters class object. The
  functions of this object returns always a string.

.. js:attribute:: AppletTCP.f

  :returns: A :ref:`fetches_class`

  This attribute contains a Fetches class object.

.. js:attribute:: AppletTCP.sf

  :returns: A :ref:`fetches_class`

  This attribute contains a Fetches class object.

.. js:function:: AppletTCP.getline(applet)

  This function returns a string containing one line from the stream. If the
  data returned doesn't contains a final '\\n' its assumed than its the last
  available data before the end of stream.

  :param class_AppletTCP applet: An :ref:`applettcp_class`
  :returns: a string. The string can be empty if we reach the end of the stream.

.. js:function:: AppletTCP.receive(applet, [size])

  Reads data from the TCP stream, according to the specified read *size*. If the
  *size* is missing, the function tries to read all the content of the stream
  until the end.

  :param class_AppletTCP applet: An :ref:`applettcp_class`
  :param integer size: the required read size.
  :returns: always return a string,the string can be empty is the connexion is
            closed.

.. js:function:: AppletTCP.send(appletmsg)

  Send the message on the stream.

  :param class_AppletTCP applet: An :ref:`applettcp_class`
  :param string msg: the message to send.

.. js:function:: AppletTCP.get_priv(applet)

  Return Lua data stored in the current transaction (with the
  `AppletTCP.set_priv()`) function. If no data are stored, it returns a nil
  value.

  :param class_AppletTCP applet: An :ref:`applettcp_class`
  :returns: the opaque data previsously stored, or nil if nothing is
     avalaible.

.. js:function:: AppletTCP.set_priv(applet, data)

  Store any data in the current HAProxy transaction. This action replace the
  old stored data.

  :param class_AppletTCP applet: An :ref:`applettcp_class`
  :param opaque data: The data which is stored in the transaction.

External Lua libraries
======================

A lot of useful lua libraries can be found here:

* `https://lua-toolbox.com/ <https://lua-toolbox.com/>`_

Redis acces:

* `https://github.com/nrk/redis-lua <https://github.com/nrk/redis-lua>`_

This is an example about the usage of the Redis library with HAProxy. Note that
each call of any function of this library can throw an error if the socket
connection fails.

.. code-block:: lua

    -- load the redis library
    local redis = require("redis");

    function do_something(txn)

       -- create and connect new tcp socket
       local tcp = core.tcp();
       tcp:settimeout(1);
       tcp:connect("127.0.0.1", 6379);

       -- use the redis library with this new socket
       local client = redis.connect({socket=tcp});
       client:ping();

    end

OpenSSL:

* `http://mkottman.github.io/luacrypto/index.html
  <http://mkottman.github.io/luacrypto/index.html>`_

* `https://github.com/brunoos/luasec/wiki
  <https://github.com/brunoos/luasec/wiki>`_

