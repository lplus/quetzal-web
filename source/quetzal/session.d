import std.stdio;
import std.algorithm;
import std.string;
import std.conv;
import std.mmfile;
import core.stdc.string;
import core.stdc.time;
import core.time;
import std.random;


template Session(T) {

    private SessionMember _session;
    @property SessionMember *Session(){
        return &_session;
    }

    struct SessionMember
    {

        static void start() {
            if (_store is null) {   // default session stroe;
                _store = new StoreFile("fcgi_session", SessionMember.sizeof);
            }
            if (_store.exists(sessionId)) {
                _store.get(sessionId, &_session);
                if(!_session.available) {
                    memset(&_session, 0, SessionMember.sizeof);
                }
            }
        }
        
        static void setStore(ISessionStore store)
        {
            _store = store;
        }
        static void store() {
            _session.updateTime = time(cast(time_t*)0);
            _store.set(sessionId, &_session);
        }
        
        static bool available() {
            return (time(cast(time_t*)0) - _session.updateTime).seconds < expiration;
        }
        
        static string sessionId() {
        	return randomUUID().toString();
        }
        static string cookieName = "QUETZAL_FCGI_SESSIONID";
        static string function() genSessionId = null;
        
        static private ISessionStore _store = null;

        static Duration expiration = 30.minutes;
        
        // data
        time_t updateTime = 0;
        T sessionMember;
        alias sessionMember this;
    }
}


interface ISessionStore
{
    void get(string key, void* valueBuf);
    void set(string key, void* valueBuf);
    bool exists(string key);
}

class StoreFile: ISessionStore
{
    string path = null;
    int depth;
    size_t fileSize;
    this(string path, size_t fileSize, int depth = 1)
    {
        if (!std.file.exists(path)) {
            std.file.mkdirRecurse(path);
        }
        this.path = path;
        this.fileSize = fileSize;
        this.depth = depth;
    }

    bool exists(string key)
    {
        if (std.file.exists(sessionFile(key))) {
            return true;
        }
        return false;
    }

    void get(string key, void* valueBuf)
    {
        auto file = sessionFile(key);
        if (std.file.exists(file)) {
            auto content = std.file.read(file);
            if (content.length == fileSize) {
                valueBuf[0 .. fileSize] = content[];
            }
        }
    }
    
    private string sessionFile(string key)
    {
        string file = path[$-1] == std.path.dirSeparator[0] ? path: path ~ std.path.dirSeparator;
        for(int i=0; i<depth; i++) {
            file ~= key[i] ~ std.path.dirSeparator;
        }
        if (!std.file.exists(file)) {
            std.file.mkdirRecurse(file);
        }
        return file ~ key;
    }
    void set(string key, void* value)
    {
        byte[] buf = new byte[fileSize];
        buf[0 .. fileSize] = cast(byte[])value[0 .. fileSize];
        std.file.write(sessionFile(key), buf);
    }
}


struct StringBuffer(ulong len)
{
    char[len] data = 0;
    size_t length = len;
    alias toString this;

    void opAssign(string val) {
        auto l = min(val.length, len);
        length = l;
        data[0 .. l] = val[0 .. l];
    }

    char opIndex(size_t i) {
        return data[i];
    }

    void opIndexAssign(char c, size_t i) {
        data[i] = c;
    }

    char[] opSlice(size_t i1, size_t i2) {
        return data[i1 .. i2];
    }

    size_t opDollar() {
        return length;
    }

    void opOpAssign(string op)(in char[] append) 
        if (op == "~")
    {
        size_t minLen = min(len, length + append.length);
        data[length .. minLen] = append[0 .. minLen - length];
    }

    string toString() {
        return  (data[len - 1] == '\0') ? 
            to!string(data.ptr): 
            to!string(data.ptr[0 .. len]);
    }
}

unittest
{
	struct Member
	{
		char c;
	    StringBuffer!10 name;
	    StringBuffer!10 desc;
    }
    StringBuffer!10 str1;
    str1 = "abc";
    str1 ~= "xxxxxxxxxx";
    writeln(str1);
    alias session = Session!Member;
    session.start;
    if (session.available) {
        string sql = "SELECT from User WHERE \nname=" ~
            session.name ~
            " AND\ndesc = " ~ session.desc;
        writeln(sql);
        sql = "xx";
        writeln(sql);
        string str = session.name;
        session.name = "abc name";
        writeln(session.name.length);
        writeln(session.name[2 .. 5]);
    }
    else {
        session.c = 'i';
        session.desc = "desc22222222222222";
        session.name = "liyunxin";
        writeln("write");
    }
    session.store;
}
