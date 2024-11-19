#include "unistd.h"

#define _WINSOCK_DEPRECATED_NO_WARNINGS
#define WIN32_LEAN_AND_MEAN
#include <WinSock2.h>
#include <Windows.h>
#include <conio.h>

static LONGLONG get_cpu_freq() {
    LARGE_INTEGER freq;
    QueryPerformanceFrequency(&freq);
    return freq.QuadPart;
}

int kill(pid_t pid, int exit_code) { return TerminateProcess((void*)pid, exit_code); }

#define NANOSEC 1000000000
#define MICROSEC 1000000

void usleep(size_t us) {
    if (us > 1000) {
        Sleep(us / 1000);
        return;
    }
    LONGLONG delta = get_cpu_freq() / MICROSEC * us;
    LARGE_INTEGER counter;
    QueryPerformanceCounter(&counter);
    LONGLONG start = counter.QuadPart;
    for (;;) {
        QueryPerformanceCounter(&counter);
        if (counter.QuadPart - start >= delta)
            return;
    }
}

void sleep(size_t ms) { Sleep(ms); }

// 将 FILETIME 转换为秒和纳秒
void filetime_to_timespec(const FILETIME* ft, struct timespec* ts) {
    ULARGE_INTEGER uli;
    uli.LowPart = ft->dwLowDateTime;
    uli.HighPart = ft->dwHighDateTime;

    // FILETIME 是自1601年1月1日以来的100纳秒间隔
    uint64_t total_nsec = uli.QuadPart * 100; // 转换为纳秒
    ts->tv_sec = (long)(total_nsec / 1000000000); // 转换为秒
    ts->tv_nsec = (long)(total_nsec % 1000000000); // 剩余的纳秒
}

// 获取系统时钟
int clock_gettime(int clk_id, struct timespec* ts) {
    if (!ts) return -1;

    if (clk_id == CLOCK_REALTIME) {
        // 获取当前时间（UTC 时间）
        FILETIME ft;
        GetSystemTimeAsFileTime(&ft);
        filetime_to_timespec(&ft, ts);
        return 0;
    } else if (clk_id == CLOCK_MONOTONIC) {
        // 获取单调时钟（高精度性能计数器）
        static LARGE_INTEGER frequency;
        static int initialized = 0;
        LARGE_INTEGER counter;

        if (!initialized) {
            QueryPerformanceFrequency(&frequency);
            initialized = 1;
        }
        QueryPerformanceCounter(&counter);

        ts->tv_sec = (long)(counter.QuadPart / frequency.QuadPart);
        ts->tv_nsec = (long)((counter.QuadPart % frequency.QuadPart) * 1000000000 / frequency.QuadPart);
        return 0;
    } else if (clk_id == CLOCK_THREAD_CPUTIME_ID) {
        // 获取当前线程的 CPU 时间
        FILETIME creation_time, exit_time, kernel_time, user_time;
        if (GetThreadTimes(GetCurrentThread(), &creation_time, &exit_time, &kernel_time, &user_time)) {
            struct timespec user_ts;
            filetime_to_timespec(&user_time, &user_ts);
            ts->tv_sec = user_ts.tv_sec;
            ts->tv_nsec = user_ts.tv_nsec;
            return 0;
        } else {
            return -1; // 获取失败
        }
    } else {
        // 不支持的时钟 ID
        return -1;
    }
}

int flock(int fd, int flag) {
    // Not implemented
    return 3;
}

int fcntl(int fd, int cmd, long arg)
{
	if (cmd == F_GETFL)
		return 0;

	if (cmd == F_SETFL && arg == O_NONBLOCK) {
		u_long ulOption = 1;
		ioctlsocket(fd, FIONBIO, &ulOption);
	}

	return 1;
}

void sigfillset(int* flag) {
    // Not implemented
}

int sigemptyset(int* set)
{
    /*Not implemented*/
    return 0;
}

void sigaction(int flag, struct sigaction* action, void* param) {
    // Not implemented
}

static void socket_keepalive(int fd) {
    int keepalive = 1;
    int ret = setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, (void*)&keepalive,
        sizeof(keepalive));

    assert(ret != SOCKET_ERROR);
}

int pipe(int fd[2]) {

    int listen_fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    struct sockaddr_in sin;
    sin.sin_family = AF_INET;
    sin.sin_addr.S_un.S_addr = inet_addr("127.0.0.1");

    srand(time(NULL));
    // use random port(range from 60000 to 60999) to simulate pipe()
    for (;;) {
        int port = 60000 + rand() % 1000;
        sin.sin_port = htons(port);
        if (!bind(listen_fd, (struct sockaddr*)&sin, sizeof(sin)))
            break;
    }

    listen(listen_fd, 5);
    printf("Windows sim pipe() listen at %s:%d\n", inet_ntoa(sin.sin_addr),
        ntohs(sin.sin_port));

    socket_keepalive(listen_fd);

    int client_fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (connect(client_fd, (struct sockaddr*)&sin, sizeof(sin)) ==
        SOCKET_ERROR) {
        closesocket(listen_fd);
        return -1;
    }

    struct sockaddr_in client_addr;
    size_t name_len = sizeof(client_addr);
    int client_sock =
        accept(listen_fd, (struct sockaddr*)&client_addr, &name_len);
    // FD_SET( clientSock, &g_fdClientSock);

    // TODO: close listen_fd

    fd[0] = client_sock;
    fd[1] = client_fd;

    socket_keepalive(client_sock);
    socket_keepalive(client_fd);

    return 0;
}

int write(int fd, const void* ptr, unsigned int sz) {

    WSABUF vecs[1];
    vecs[0].buf = ptr;
    vecs[0].len = sz;

    DWORD bytesSent;
    if (WSASend(fd, vecs, 1, &bytesSent, 0, NULL, NULL))
        return -1;
    else
        return bytesSent;
}

int read(int fd, void* buffer, unsigned int sz) {

    WSABUF vecs[1];
    vecs[0].buf = buffer;
    vecs[0].len = sz;

    DWORD bytesRecv = 0;
    DWORD flags = 0;
    if (WSARecv(fd, vecs, 1, &bytesRecv, &flags, NULL, NULL)) {
        if (WSAGetLastError() == WSAECONNRESET)
            return 0;
        return -1;
    }
    else{
        return bytesRecv;
    }
}

int close(int fd) {
    shutdown(fd, SD_BOTH);
    return closesocket(fd);
}

int daemon(int a, int b) {
    // Not implemented
    return 0;
}

char* strsep(char** stringp, const char* delim) {
    char* s;
    const char* spanp;
    int c, sc;
    char* tok;
    if ((s = *stringp) == NULL)
        return (NULL);
    for (tok = s;;) {
        c = *s++;
        spanp = delim;
        do {
            if ((sc = *spanp++) == c) {
                if (c == 0)
                    s = NULL;
                else
                    s[-1] = 0;
                *stringp = s;
                return (tok);
            }
        } while (sc != 0);
    }
    /* NOTREACHED */
}