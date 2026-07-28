#include "mex.h"
#include "windows.h"

typedef short ( * InterfaceInputPort) ( short PortAddress );
typedef void ( * InterfaceOutputPort )( short PortAddress, short data );

#define MESSAGE_LENGTH 200

InterfaceInputPort InputPort;
InterfaceOutputPort OutputPort;

HINSTANCE handle = NULL;
INT WaitResult;
UINT WaitCount = 0;
BOOL IsInitialised = false;
BOOL MessageEnable = true;
int	Address;

char InfoMsg[ MESSAGE_LENGTH ] = "No info.";
char ErrorMsg[ MESSAGE_LENGTH ]= "No error.";

int Initialise( const char * path )
{
	char fullpath1[256] = { 0 };
	char fullpath2[256] = { 0 };

	strcat( fullpath1, path );
	strcat( fullpath1, "\\inpout32.dll");

	handle = LoadLibrary( fullpath1 );
	
	if ( !handle )
		return -1;
	
	InputPort = 
		(InterfaceInputPort) GetProcAddress( handle, "Inp32" );

	if ( ! InputPort )
	{
		FreeLibrary( handle );
		return -2;
	}

	OutputPort = 
		(InterfaceOutputPort) GetProcAddress( handle, "Out32" );

	if ( ! OutputPort )
	{
		FreeLibrary( handle );
		return -2;
	}

	return 1;
}

void PrintInfo( const char * info )
{
	strcpy( InfoMsg, info );
	if ( MessageEnable ) mexPrintf( InfoMsg );
}

void PrintError( const char * error )
{
	strcpy( ErrorMsg, error );
	mexErrMsgTxt( ErrorMsg );
}

void mexFunction( int nlhs, mxArray * plhs[], int nrhs, const mxArray * prhs[] )
{	
	char
		* argument1,
		* argument2,
		* argument3;
	double 
		* dataPtr,
		* dataPtr2;
	int	
	    result,
		resultInitialise;
	unsigned int
		i;

	if ( nrhs < 1 ) PrintError("PARALLELPORT_INPOUT32 ERROR : YOU MUST PROVIDE AT LEAST ONE ARGUMENT.");
	
	argument1 = mxArrayToString(prhs[0]);

	for ( i = 0; i < strlen( argument1 ) ; ++i )
		 argument1[i] = toupper(argument1[i]) ; 

	if ( strcmp( argument1, "INPUT" ) == 0 )
	{
		if ( nlhs > 1 ) PrintError("PARALLELPORT_INPOUT32 ERROR : YOU CANNOT ASSIGN THE RESULT TO MORE THAN ONE VALUE.");
		if ( nrhs > 1 ) PrintError("PARALLELPORT_INPOUT32 ERROR : THERE IS NOT A SECOND ARGUMENT.");
		
		result = InputPort( Address );
		plhs[0] = mxCreateDoubleMatrix(1, 1, mxREAL);
		dataPtr = (double *) mxGetPr( plhs[0] );
		*dataPtr = result;
	}
	else if ( strcmp( argument1, "OUTPUT" ) == 0 )
	{
		if ( nlhs > 0 ) PrintError("PARALLELPORT_INPOUT32 ERROR : YOU CANNOT ASSIGN THE RESULT");
		if ( nrhs > 2 ) PrintError("PARALLELPORT_INPOUT32 ERROR : THERE IS NOT A THIRD ARGUMENT.");
		
		dataPtr = (double *) mxGetPr( prhs[1] );
		OutputPort( Address, *dataPtr );
	}
	else if ( strcmp( argument1, "INIT") == 0 )
	{
		if ( nlhs > 0 ) PrintError("PARALLELPORT_INPOUT32 ERROR : YOU CANNOT ASSIGN A RESULT WITH THIS CALL.");
		if ( nrhs < 3 ) PrintError("PARALLELPORT_INPOUT32 ERROR : YOU MUST PROVIDE THREE ARGUMENTS.");
		
		argument2 = mxArrayToString(prhs[1]);
				
		dataPtr = (double *) mxGetPr( prhs[2] );
		Address = (int) *dataPtr;
		
		resultInitialise = Initialise( argument2 );

		if ( resultInitialise == -1 )
		{
			handle = NULL;
			PrintError("PARALLELPORT_INPOUT32 ERROR : THE INPOUT32.DLL FILE COULD NOT BE LOADED."); 
		}

		if ( resultInitialise == -2 )
		{
			handle = NULL;
			PrintError("PARALLELPORT_INPOUT32 ERROR : SOME INTERFACE(S) IN THE INPOUT32.DLL FILE COULD NOT BE LOADED."); 
		}

		PrintInfo("PARALLELPORT_INPOUT32-INFO : DLL file initialization OK.\n"); 
		
	}

}


