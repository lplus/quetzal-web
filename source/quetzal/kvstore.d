module quetzal.kvstore;
import std.conv;
import std.string;
import core.sys.posix.unistd;
import core.sys.posix.fcntl;
import core.sys.posix.sys.stat;
import core.sys.posix.sys.mman;
import core.stdc.errno;
import core.stdc.stdio;
import core.stdc.string;

interface IKvStore
{
	void set(T)(string key, T value);
	T get(T)(string key);
}

class KvStoreException : Exception
{
	int _errno;
    @safe pure nothrow this(string msg, int errno,  string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {   
    	_errno = errno;
        super(msg, file, line, next);
    }   
    
    int errno()
    {
    	return _errno;
    }
}


class StorePosixShm:IKvStore
{
	private string _name;
	private ulong _size;
	private int shmFd;
	private byte* _addr;
	this()
	{
		this("FCGI_KVSTORE");
	}

	this(string name, ulong size = 4096)
	{
		_name = name;
		_size = size;
		shmFd = shm_open(toStringz(_name), O_CREAT | O_RDWR, S_IRUSR | S_IWUSR);
		if (shmFd <0) {
			throwException("open posix shared memary object ");
		}
		
		if (ftruncate(shmFd, _size) <0) {
			close(shmFd);
			throwException("truncate " ~ to!string(_size) ~ " bytes");
		}
		
		void *addr = mmap(null, _size, PROT_READ | PROT_WRITE, MAP_SHARED, shmFd, 0);
		if (addr == MAP_FAILED) {
			close(shmFd);
			throwException("mapping of " ~ to!string(_size) ~ "bytes");
		}
		close(shmFd);
		_addr = cast(byte*)addr;
	}
	
	void free()
	{
		shm_unlink(toStringz(_name));
	}

	void throwException(string info, string file = __FILE__, size_t line = __LINE__) 
	{
        throw new KvStoreException(info ~ ":" ~ to!string(strerror(errno)), errno, file, line);
	}

	void get(T)(string key, T value)
	{
		
	}
	
	T get(T)(string key) 
	{
		
	}
	
}

class StoreMmFile:IKvStore
{
	this(string name)
	{
		
	}
	void get(T)(string key, T value)
	{
		
	}
	
	T get(T)(string key) 
	{
		
	}
}