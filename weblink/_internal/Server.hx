package weblink._internal;
// import hl.uv.Loop.LoopRunMode;
import haxe.MainLoop;
import haxe.io.Bytes;
import haxe.http.HttpMethod;
import sys.net.Host;
import weblink._internal.Socket;

class Server {
    //var sockets:Array<Socket>;
    var server:asys.net.Server;
    var parent:Weblink;
    var running:Bool = true;
    // var loop:hl.uv.Loop;

    public function new(port:Int,parent:Weblink) {
        this.parent = parent;
		// loop = new hl.uv.Loop();

		server = asys.Net.createServer({
			listen: Tcp({
				host: "0.0.0.0",
				port: port
			})
		}, handleClient);

		server.errorSignal.on(err -> trace(err));
    }

	function handleClient(client:asys.net.Socket) {
		var request:Request = null;
		var done:Bool = false;

		client.dataSignal.on(data -> @:privateAccess {
			if (done || data == null) {
				//sockets.remove(socket);
				client.destroy();
				return;
			}

			if (request == null) {
				var lines = data.toString().split("\r\n");
				request = new Request(lines);

				if (request.pos >= request.length) {
					done = true;
					complete(request,client);
					return;
				}
			} else if (!done) {
				var length = request.length - request.pos < data.length ? request.length - request.pos : data.length;
				request.data.blit(request.pos,data,0,length);
				request.pos += length;

				if (request.pos >= request.length) {
					done = true;
					complete(request,client);
					return;
				}
			}

			if (request.chunked) {
				request.chunk(data.toString());
				if (request.chunkSize == 0) {
					done = true;
					complete(request,client);
					return;
				}
			}

			if (request.method != Post) {
				done = true;
				complete(request,client);
			}
		});
	}

    private inline function complete(request:Request,socket:asys.net.Socket)
    {
        @:privateAccess var response = request.response(this,socket);
        switch (request.method)
        {
            case Get: @:privateAccess parent._getEvent(request,response);
            case Post: @:privateAccess parent._postEvent(request,response);
            case Head: @:privateAccess parent._headEvent(request,response);
            default: trace('Request method: ${request.method} Not supported yet');
        }
    }
    public function update(blocking:Bool=true)
    {
		trace('update');
        do {
            @:privateAccess MainLoop.tick(); //for timers
            hl.Uv.run(RunDefault);
            // hl.Uv.run(RunNoWait);
        } while (running && blocking);
    }
    public inline function closeSocket(socket:asys.net.Socket)
    {
        //sockets.remove(socket);
        socket.destroy();
    }
    public function close()
    // override function close(#if (hl && !nolibuv) ?callb:() -> Void #end)
    {
		trace('close');
        //remove sockets array as well
        /*for (socket in sockets)
        {
            socket.close();
        }*/
        //sockets = [];
        running = false;
        server.close();
    }
}
