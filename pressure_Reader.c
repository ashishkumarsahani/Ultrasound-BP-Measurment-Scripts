#include <windows.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <conio.h>
#include <process.h> //used for thread
#include "mex.h"
#include <time.h>
#include <Winbase.h>
#include <stdio.h>
#include <limits.h>
#include <time.h>

HANDLE USMutex; 

HANDLE serialinstance;
DWORD      dwStoredFlags;
DWORD      dwRes;
DWORD      dwCommEvent;
OVERLAPPED osStatus = {0};
BOOL       fWaitingOnStat;
DCB dcb;
COMMTIMEOUTS timeouts;
COMMCONFIG serialconfig;
unsigned __int8 latest_Data_Bytes_Array[10]; 
int current_Byte_Location =0;
int thread_Started=0;
double currentPressureBytes[4];
//If you experience slow streaming. Check baud rate and latency in hardware manager
int start_Time_Stamped_Array = 0 ;
long time_Stamped_Array_Index =0;
LARGE_INTEGER curr_Time_us;
LARGE_INTEGER start_Time_us;
double time_Stamped_Data_Time[10000];
double time_Stamped_Data[40000];
double PCFreq = 0.0;
__int64 CounterStart = 0;


#if defined(_MSC_VER) || defined(_MSC_EXTENSIONS)
  #define DELTA_EPOCH_IN_MICROSECS  11644473600000000Ui64
#else
  #define DELTA_EPOCH_IN_MICROSECS  11644473600000000ULL
#endif
 
struct timezone 
{
  int  tz_minuteswest; /* minutes W of Greenwich */
  int  tz_dsttime;     /* type of dst correction */
};
 
int gettimeofday(struct timeval *tv)
{
  FILETIME ft;
  unsigned __int64 tmpres = 0;
  static int tzflag;
 
  if (NULL != tv)
  {
    GetSystemTimeAsFileTime(&ft);
 
    tmpres |= ft.dwHighDateTime;
    tmpres <<= 32;
    tmpres |= ft.dwLowDateTime;
 
    /*converting file time to unix epoch*/
    tmpres -= DELTA_EPOCH_IN_MICROSECS; 
    tmpres /= 10;  /*convert into microseconds*/
    tv->tv_sec = (long)(tmpres / 1000000UL);
    tv->tv_usec = (long)(tmpres % 1000000UL);
  }
 
  return 0;
}

int openSerial_Port(){
    // Declare variables and structures
    DCB dcbSerialParams = {0};
    COMMTIMEOUTS timeouts = {0};
         
    // Open the highest available serial port number
    fprintf(stderr, "Opening serial port...");
    serialinstance = CreateFile(
                "\\\\.\\COM8", GENERIC_READ|GENERIC_WRITE, 0, NULL,
                OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL );
    if (serialinstance == INVALID_HANDLE_VALUE)
    {
            fprintf(stderr, "Error\n");
            return 1;
    }
    else fprintf(stderr, "OK\n");
     
    // Set device parameters (38400 baud, 1 start bit,
    // 1 stop bit, no parity)
    dcbSerialParams.DCBlength = sizeof(dcbSerialParams);
    if (GetCommState(serialinstance, &dcbSerialParams) == 0)
    {
        fprintf(stderr, "Error getting device state\n");
        CloseHandle(serialinstance);
        return 1;
    }
     
    dcbSerialParams.BaudRate = CBR_115200;
    dcbSerialParams.ByteSize = 8;
    dcbSerialParams.StopBits = ONESTOPBIT;
    dcbSerialParams.Parity = NOPARITY;
    if(SetCommState(serialinstance, &dcbSerialParams) == 0)
    {
        fprintf(stderr, "Error setting device parameters\n");
        CloseHandle(serialinstance);
        return 1;
    }
 
    // Set COM port timeout settings
    timeouts.ReadIntervalTimeout = 1;
    timeouts.ReadTotalTimeoutConstant = 1;
    timeouts.ReadTotalTimeoutMultiplier = 1;
    timeouts.WriteTotalTimeoutConstant = 1;
    timeouts.WriteTotalTimeoutMultiplier = 1;
    if(SetCommTimeouts(serialinstance, &timeouts) == 0)
    {
        fprintf(stderr, "Error setting timeouts\n");
        CloseHandle(serialinstance);
        return 1;
    }
    return 0;
}

unsigned __int8 rs_getch()
{
    int i=0;
    unsigned __int8 ret[2];
    unsigned __int8 rxchar;
    float pressure_Val;
    //BOOL bReadRC;
    static DWORD iBytesRead;
    ReadFile(serialinstance, &rxchar, 1, &iBytesRead, NULL);
    if((int)iBytesRead==0)
        return 0;

    for(i=0;i<9;i++)
        latest_Data_Bytes_Array[i]= latest_Data_Bytes_Array[i+1];
    latest_Data_Bytes_Array[9] = rxchar;
    
    if(latest_Data_Bytes_Array[0]==170 && latest_Data_Bytes_Array[1]==59)
    {
        int indices_For_Data[4];
        int data_Index_Count=0;
        for(i=2;i<9;i++)
        {
            if(latest_Data_Bytes_Array[i] !=170){
                indices_For_Data[data_Index_Count] = i;
                //printf("%04x ",latest_Data_Bytes_Array[indices_For_Data[data_Index_Count]]);
                (&pressure_Val)[data_Index_Count]= latest_Data_Bytes_Array[indices_For_Data[data_Index_Count]];
                currentPressureBytes[data_Index_Count] = (double)latest_Data_Bytes_Array[indices_For_Data[data_Index_Count]];
                data_Index_Count = data_Index_Count+1;
            }
            else{
                indices_For_Data[data_Index_Count] = (i+1);
                i=i+1;
                //printf("%04x ",latest_Data_Bytes_Array[indices_For_Data[data_Index_Count]]);
                (&pressure_Val)[data_Index_Count]= latest_Data_Bytes_Array[indices_For_Data[data_Index_Count]];
                currentPressureBytes[data_Index_Count] = (double)latest_Data_Bytes_Array[indices_For_Data[data_Index_Count]];
                data_Index_Count = data_Index_Count+1;
            }
            if(data_Index_Count ==4)
                break; 
        }
        //printf("\n%f",51.7*pressure_Val);
        //printf("\n");
    }
    return rxchar; 
}

void ClearStream()
{
    char rxchar;
    BOOL bReadRC;
    static DWORD iBytesRead;
    while(iBytesRead!=0)
                         ReadFile(serialinstance, &rxchar, 1, &iBytesRead, NULL);
}

void start_DAQ() //send /r/n at the end of command
{
    BOOL bWriteRC;
    static DWORD iBytesWritten;
    unsigned __int8 command_String[4];
    command_String[0] = 80;
    command_String[1] = 67;
    command_String[2] = 13;
    command_String[3] = 10;
    if(!WriteFile(serialinstance, command_String, 4, &iBytesWritten,NULL))
    {
        mexPrintf("Error in writting\n");
    }   
    //mexPrintf("%d bytes written\n", iBytesWritten);
}

void set_Max_Rate() //send /r/n at the end of command
{
    BOOL bWriteRC;
    static DWORD iBytesWritten;
    unsigned __int8 command_String[9]; //RATE 08
    command_String[0] = 0x52; 
    command_String[1] = 0x41; 
    command_String[2] = 0x54;
    command_String[3] = 0x45;
    command_String[4] = 0x20;
    command_String[5] = 0x30;
    command_String[6] = 0x38;
    command_String[7] = 0x0d;
    command_String[8] = 0x0a;
    if(!WriteFile(serialinstance, command_String, 9, &iBytesWritten,NULL))
    {
        mexPrintf("Error in writting\n");
    }   
    //mexPrintf("%d bytes written\n", iBytesWritten);
}

void get_Serial_Num() //send /r/n at the end of command
{
    BOOL bWriteRC;
    static DWORD iBytesWritten;
    unsigned __int8 command_String[5];
    command_String[0] = 83;
    command_String[1] = 78;
    command_String[2] = 82;
    command_String[3] = 13;
    command_String[4] = 10;
    if(!WriteFile(serialinstance, command_String, 5, &iBytesWritten,NULL))
    {
        mexPrintf("Error in writting\n");
    }   
    //mexPrintf("%d bytes written\n", iBytesWritten);
}

void stop_DAQ() //send /r/n at the end of command
{
    BOOL bWriteRC;
    static DWORD iBytesWritten;
    unsigned __int8 command_String[4];
    command_String[0] = 80;
    command_String[1] = 83;
    command_String[2] = 13;
    command_String[3] = 10;
    if(!WriteFile(serialinstance, command_String, 4, &iBytesWritten,NULL))
    {
        mexPrintf("Error in writting\n");
    }   
    //mexPrintf("%d bytes written\n", iBytesWritten);
}

void close_Port(){
    CloseHandle(serialinstance);
}

void StartCounter()
{
    LARGE_INTEGER li;
    if(!QueryPerformanceFrequency(&li))
    printf("QueryPerformanceFrequency failed!\n");

    PCFreq = (double)(li.QuadPart)/1000000.0;

    QueryPerformanceCounter(&li);
    CounterStart = li.QuadPart;
}
double GetCounter()
{
    LARGE_INTEGER li;
    QueryPerformanceCounter(&li);
    return (double)((li.QuadPart-CounterStart)/PCFreq);
}

void cdecl AcqThread(LPVOID pVoid){ 
    while(1)
    {
        WaitForSingleObject( 
                USMutex,    // handle to mutex
                INFINITE);  // no time-out interval
        currentPressureBytes[0]=-1;
        GETCH_AGAIN:
        rs_getch();
        if(currentPressureBytes[0]==-1)
            goto GETCH_AGAIN;
        if(thread_Started==0)
        {
            ReleaseMutex(USMutex);
            return;
        }
        if(start_Time_Stamped_Array == 1)
        {
            if(time_Stamped_Array_Index ==0)
            {  
                StartCounter();
                time_Stamped_Data_Time[(int)(time_Stamped_Array_Index/4)] = 0;
            }
            else
            {
                QueryPerformanceCounter(&curr_Time_us);
                time_Stamped_Data_Time[(int)(time_Stamped_Array_Index/4)] = GetCounter();
            }
            time_Stamped_Data[time_Stamped_Array_Index] = currentPressureBytes[0];
            time_Stamped_Data[time_Stamped_Array_Index+1] = currentPressureBytes[1];
            time_Stamped_Data[time_Stamped_Array_Index+2] = currentPressureBytes[2];
            time_Stamped_Data[time_Stamped_Array_Index+3] = currentPressureBytes[3];
            time_Stamped_Array_Index=time_Stamped_Array_Index+4;
            if(time_Stamped_Array_Index > 40000)
                time_Stamped_Array_Index=0;
        }
        ReleaseMutex(USMutex);
    }        
}

void mexFunction (int nlhs, mxArray * plhs[], int nrhs, const mxArray * prhs[]){
    int ThreadNr,port_Opened_Successfully, l;
    double command;
    double *current_Pressure;
    double error_Code =-1;
    command = mxGetScalar(prhs[0]);
    
    if(command ==1.0 && thread_Started == 0)
    {
        port_Opened_Successfully=openSerial_Port();
        Sleep(1000);
        if(port_Opened_Successfully ==1){
           plhs[0] = mxCreateDoubleMatrix(1, 1, mxREAL);
           memcpy(mxGetPr(plhs[0]),&error_Code,1*sizeof(double));
           return;
        }
        set_Max_Rate();
        Sleep(2000);
        start_DAQ();
        thread_Started=1;
        USMutex = CreateMutex( 
        NULL,              // default security attributes
        FALSE,             // initially not owned
        NULL);             // unnamed mutex
        _beginthread( AcqThread, 0, &ThreadNr );
    }
    else if(command ==2.0 && thread_Started == 1)
    {
        WaitForSingleObject( 
                USMutex,    // handle to mutex
                INFINITE);  // no time-out interval
        thread_Started=0;
        ReleaseMutex(USMutex);
        Sleep(10);
        stop_DAQ();
        close_Port();
    }
    else if(command ==3.0 && thread_Started == 1)
    {
        plhs[0] = mxCreateDoubleMatrix(4, 1, mxREAL);
        current_Pressure = mxGetPr(plhs[0]);
        WaitForSingleObject( 
                USMutex,    // handle to mutex
                INFINITE);  // no time-out interval
        memcpy(current_Pressure,currentPressureBytes,4*sizeof(double));
        ReleaseMutex(USMutex);
    }
    else if(command ==4.0 && thread_Started == 1 && start_Time_Stamped_Array ==0)
    {//Limited to only 10 seconds of time stamped data command 5 must be passed before elapse of 10 s to get predictable results.
        WaitForSingleObject( 
                USMutex,    // handle to mutex
                INFINITE);  // no time-out interval
        time_Stamped_Array_Index =0;
        for(l = 0; l<10000; l++)
        {
            time_Stamped_Data_Time[l] = 0;
        }
        for(l = 0; l<40000; l++)
        {
            time_Stamped_Data[l] = 0;
        }
        start_Time_Stamped_Array =1;
        ReleaseMutex(USMutex);
    }
    else if(command ==5.0 && thread_Started == 1 && start_Time_Stamped_Array ==1)
    {
        WaitForSingleObject( 
                USMutex,    // handle to mutex
                INFINITE);  // no time-out interval
        plhs[0] = mxCreateDoubleMatrix(10000, 1, mxREAL);
        plhs[1] = mxCreateDoubleMatrix(40000, 1, mxREAL);
        current_Pressure = mxGetPr(plhs[0]);
        memcpy(mxGetPr(plhs[0]),time_Stamped_Data_Time,10000*sizeof(double));
        memcpy(mxGetPr(plhs[1]),time_Stamped_Data,40000*sizeof(double));
        start_Time_Stamped_Array =0;
        time_Stamped_Array_Index=0;
        ReleaseMutex(USMutex);
    }
    else
    {
        plhs[0] = mxCreateDoubleMatrix(1, 1, mxREAL);
        memcpy(mxGetPr(plhs[0]),&error_Code,1*sizeof(double));
    }
    return; 
}