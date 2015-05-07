/**
 * Web 框架相关程序
 * 处理:
 * Url映射
 * GET,POST，文件上传 数据
 * Ak
 * Server 
 * Request
 * Response
 * ResponseTemplate
 */
module quetzal.framework;
//import quetzal.fcgi;
import std.stdio;


import std.array;
import std.string;
import std.conv;
import core.runtime;
import std.ascii: toUpperChar = toUpper;
import object;
import std.process;
import std.concurrency;
import quetzal.fcgiapp;


Response response;
Request request;

// for short usage
void put(T...)(T s)
{
    response.write(s);
}
void cookie(in char[] key, in char[] value)
{
	
}

void putHeader(string item)
{
    response.writeHeader(item);
}

void flush()
{
    response.flush();
}

void render(string tplName, vars...)() 
{
    auto tpl = HtmlTemplate!(tplName, vars)();
    put(typeid(typeof(tpl)));
    tpl.show();
}



/**
 *
 */
abstract final class fcgiEnv
{
static:
    string opIndex(in char[] name) 
    {   
        if (name == "") return "";

        return getImpl(name);
    }
    
    string get(in char[] name, string defaultValue = null) //TODO: nothrow
    {
        string value = getImpl(name);
        return (value is null) ? defaultValue : value;
    }

    private string getImpl(in char[] name)
    {
        char *val = FCGX_GetParam(toStringz(name), Server.fcgxRequest.envp);
        return (val is null) ? null: to!string(val);
    }

    string[string] toAA() 
    {
		string[string] aa;
		for (int i=0; Server.fcgxRequest.envp[i] != null; ++i) 
		{    
			immutable varDef = to!string(Server.fcgxRequest.envp[i]);
			immutable eq = std.string.indexOf(varDef, '=');
			assert (eq >= 0);

			immutable name = varDef[0 .. eq]; 
			immutable value = varDef[eq+1 .. $];

			if (name !in aa)  aa[name] = value;
		}  

		return aa;
    }
}


/**
 *
 */
abstract final class Server
{
static:
	__gshared uint _threadNum;
	
    synchronized private int accept()
    {
        int rc = FCGX_Accept_r(&fcgxRequest);
		return rc;
    }

    private FCGX_Request fcgxRequest;

    __gshared bool fcgxShutdownPending = false; 
    void workerThread(uint threadNum, string handlerPackName)
    {
		_threadNum = threadNum;
        int rc;
        FCGX_InitRequest(&fcgxRequest, 0, 0);

        if (getHandlerName is null) {

            getHandlerName = function() {
                string handler_info = fcgiEnv.get("REQUEST_URI", "/");

                if (handler_info == "/") {
                    return ".index.IndexHandler";
                }
                char[] handler_name = cast(char[])handler_info[].save;
                uint upper_pos = 0;
                int replace_cnt = 0;
                foreach(k, ref c; handler_name) {
                    if (c == '/') {
                        c = '.';
                        upper_pos = cast(uint)k + 1;
                        replace_cnt ++;
                        continue;
                    }
                    if (c == '.') {
                        handler_name = handler_name[0 .. k];
                        break;
                    }
                }
                handler_name[upper_pos] = cast(char)toUpperChar(handler_name[upper_pos]);
                if (replace_cnt == 1) {
                    handler_name = ".index" ~ handler_name;
                }
                return to!string(handler_name ~ "Handler");
            };
        }


        for(;;)
        {
            if (fcgxShutdownPending) {
                writeln("break thread loop", threadNum);
                break;
            }
            stdout.writeln("begin accept ok");
            stdout.flush();
            rc = (threadNum == 0 || fcgxRequest.ipcFd > -1) ? FCGX_Accept_r(&fcgxRequest): accept();
            if (rc < 0)
            {
                writeln("accept error exit:", threadNum);
                break;
            }
            stdout.writeln("accept ok");
			stdout.flush();
            auto subHandlerName = getHandlerName();

            auto handlerName = handlerPackName ~ subHandlerName;
            RequestHandler requestHandler = cast(RequestHandler) Object.factory(handlerName);
            response = new Response(fcgxRequest.out_, fcgxRequest.err);
            if (requestHandler is null)
            {
                response << "Content-Type:text/html\r\n\r\n" << "<h1>404 Handler Not Found</h1>";
                continue;
            }
            request = new Request(fcgxRequest.in_);
            //fcgxRequest.appStatus = 404;
			scope(failure)
			{
				FCGX_PutStr("++++++++++".ptr, 10, fcgxRequest.err);
			}
            //requestHandler._request = _request;
            //requestHandler._response = _response;
            requestHandler.init();
            auto requestMethod = fcgiEnv["REQUEST_METHOD"];
            stdout.writeln("call method");
			stdout.flush();
			try
			{
				if (requestMethod == "POST")
					requestHandler.onPost();
				else
					requestHandler.onGet();
			}
			catch(Exception e)
			{
				string msg = to!string(e);
				FCGX_PutStr(msg.ptr, cast(int)msg.length, fcgxRequest.err);
				response << msg;
			}
			stdout.writeln("call method complite");
			stdout.flush();
			response << threadNum << "pid:" << getpid();
			response.flush();
			FCGX_Finish_r(&fcgxRequest);
			stdout.writeln("finish");
			stdout.flush();
		}
	}


    string function() getHandlerName = null;

    bool hasRun = false;
    
    /**
     * <executable> -s stop|reload|restart
     * <executable> -p10 -t10
     */
    void start(string handlerPackageName, int nservers=1, int nworkers=0) {
        if (hasRun) {
            return ;
        }
        hasRun = true;

        FCGX_Init();
        Tid[] workers;
        workers ~= thisTid;
        if (nworkers >0) {

            for(int i=1; i<=nworkers; i++)
            {
                workers ~= spawn(&workerThread, i, handlerPackageName);
            }
			auto workerMsg = receiveOnly!(uint, bool);
			send(workers[workerMsg[0]], true);
        }
        else {
            workerThread(0, handlerPackageName);
        }

    }
}


class RequestHandler
{
    
    //mixin(import(tplName));
    protected this(){}


    void onGet()
    {
        response << "Default Handler onGet";
    }

    void onPost()
    {
        response << "Default Handler onPost";
    }

    void init(){}
}

class Request
{
    FCGX_Stream* _in;
    byte[] buffer;
    string[string] params;
    this(FCGX_Stream* in_)
    {
        this._in = in_;
        if (fcgiEnv["REQUEST_METHOD"] == "POST"){
        	auto slen = fcgiEnv["CONTENT_LENGTH"];
        	if (slen == "" || slen == "0") {
        		return;
        	}
        	
        	int contentLength = to!int(slen);
        	buffer = new byte[contentLength];
        	int hasRead = 0, nread;
        	while(true)
        	{
        		nread = FCGX_GetStr(cast(char*)(buffer.ptr+hasRead), contentLength, _in);
        		if (nread < contentLength) {
        			hasRead += nread;
        			continue;
        		}
        		break;
        	}
        }
        else if(fcgiEnv["REQUEST_METHOD"] == "GET"){
        	if (fcgiEnv["QUERY_STRING"] != "") {
        		buffer = cast(byte[])fcgiEnv["QUERY_STRING"].dup;
        	}
        }
        
        parseData();
        put(cast(char[])buffer);
    }
    
    void parseData() {
    	if (buffer.length == 0) {
    		return;
    	}
    	if(startsWith(fcgiEnv["CONTENT_TYPE"], "multipart/form-data")) {
        	
    	}
    	else {
    		string k;
    		foreach(sv; splitter(buffer, "&")) {
    			auto kv = splitter(sv, "=");
    			k = to!string(cast(char[])kv.front());
    			kv.popFront();
    			params[k] = to!string(cast(char[])kv.front());
    		}
    		
    		put(params);
    	}
    }
    
    void parseFormData() {
    	
    }
    
    // querystring, post
    T get(T)() 
    {
    	
    }
    
    int read(byte[] buf) {
    	return FCGX_GetStr(cast(char*)buf.ptr, cast(int)buf.length, _in);
    }
    string getCookie(in char key) 
    {
    	return "";
    }
}

class Response
{
	char[] bufHead;
	char[] bufBody;
	char[] cookie;

    private FCGX_Stream* _out;
    private FCGX_Stream* _err;

    this(FCGX_Stream *out_, FCGX_Stream* err)
    {
        this._out = out_;
        this._err = err;
    }

    void endResponse() {
    	FCGX_ShutdownPending();
    }
    Response opBinary(string op, T)(T w)
    {
        static if(op == "<<")
        {
            write(w);
            return this;
        }
        else static assert(0, "Operator "~op~" not implemented");
        
    }

    void writebr(T...)(T args)
    {
        write(args, "<br />");
    }

    bool noheader = true;
    void writeHeader(in char[] headerItem)
    {
		bufHead ~= headerItem ~ "\r\n";
		//stdout.writeln(headerItem);
		//stdout.flush();
        //FCGX_PutStr(headerItem.ptr, cast(int)headerItem.length, _out);
    }

    void setCookie(in char[] key, in char[] value)
    {
    	cookie ~= key ~ "=" ~ value ~ ";";
    }
    void write(T...)(T args)
    {
        foreach(arg; args)
        {
            bufBody ~= to!string(arg);
            //FCGX_PutStr(output.ptr, cast(int)output.length, _out);
        }
    }

    bool noHeader = true;
    void flush()
    {
        if (bufHead.length == 0) {
            writeHeader("Content-Type: text/html\r\n");
        }
        if (noHeader)
        {
        //    writeHeader("Content-Length:" ~ to!string(bufBody.length) ~ "\r\n");
        	if (cookie.length >0) {
            	writeHeader("Set-Cookie:" ~ cookie);
            }
            FCGX_PutStr(bufHead.ptr, cast(int)bufHead.length, _out);
            
            FCGX_PutStr("\r\n".ptr, 2, _out);
            noHeader = false;
        }
		FCGX_PutStr(bufBody.ptr, cast(int)bufBody.length, _out);
        FCGX_FFlush(_out);
		//bufHead = [];
		bufBody = [];
    }


}


template varAlias(vars...)
{
    static if( vars.length >0){
        enum string varAlias = "alias " ~__traits(identifier, vars[vars.length-1]) ~ 
        " = vars["~to!string(vars.length -1)~"] " ~ ";\n" ~ varAlias!(vars[0 .. $ -1]);
    } 
    else enum string varAlias = "";
}
/**
 *
 *
 */
struct HtmlTemplate(string tplFile, vars...)
{
    mixin(varAlias!(vars));
    void show() {
        mixin(import(tplFile ~ ".d"));
    }
}




unittest
{
    stdout = File("stdout.txt", "a");
    stderr = File("stderr.txt", "a");
    Server.run("example.handler", 0);
}

