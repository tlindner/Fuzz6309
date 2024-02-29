#include <stdlib.h>
#include <stdio.h>
#include <string.h>

/* 6309 DIVD fuzzing disk
   This command will create two disk images.
   One disk image will contain randomized parameteres for the 6309 DIVD instruction.
   
   A program "TEST" will read the parameters, perform the instruction and write the result
   to a results disk.
   
   A second program "CHECK" will read the parameters, perform the instruction and compare the
   result with the data on the result disk. The first mismatch will be reported.
   
   The work flow is thus:
   
   1. Use this program to create a set of fuzzing disks.
   2. Mount the test and results disk on a real 6309 CoCo. Drive 0 and 1.
   3. Run the "TEST" program. Wait for it to complete.
   4. Transfer the two disk images to a machine with an emulator.
   5. Mount the two images.
   6. Run the "CHECK" program. The first mis-match will be reported.
   
   The DIVD parameters are constrained:
   1. The Condition Code register will only randomize the flags
   2. There will be no zero divisors.
   
*/

union Data {
   long rnd;
   unsigned char buf[sizeof(long)];
} data; 

void writeSector( FILE *file )
{
	union Data v;

	for(int i=0; i<64; i++ )
	{
		v.rnd = random();

		// check for zero divisor
		while( v.buf[3] == 0 )
		{
			// re-roll
			v.rnd = random();
		}

		v.buf[0] &= 0x2f; /* keep flags */
		v.buf[0] |= 0xd0; /* disable interrupts */
		
		/* Data packet for DIVD:
		 CC, A, B, divisor
		*/
		
		fwrite( v.buf, 1, 4, file );
	}
}

void writeTrack( FILE *file)
{
	for( int i=0; i<18; i++ )
	{
		writeSector(file);
	}
}

void writeSectorFF( FILE *file )
{
	unsigned char data[256];
	memset(data, 0xff, 256);
	fwrite( data, 1, 256, file );
}

void writeTrackFF( FILE *file )
{
	for( int i=0; i<18; i++ )
	{
		writeSectorFF(file);
	}
}

void writeSectorFAT( FILE *file )
{
	unsigned char data;
	data = 0xff;
	
	for( int i=0; i<68; i++ )
	{
		fwrite( &data, 1, 1, file );
	}
	
	data = 0x00;
	
	for( int i=68; i<256; i++ )
	{
		fwrite( &data, 1, 1, file );
	}
}

void writeTrackDirectory( FILE *file )
{
	writeSectorFF(file);
	writeSectorFAT(file);
	
	for( int i=0; i<16; i++ )
	{
		writeSectorFF(file);
	}
}
	
int main( int argc, char *argv[] )
{
	FILE *out;
	srandomdev();
	
	if(argc != 2 )
	{
		fprintf( stderr, "Need output filename.\n");
		return -1;
	}

	char testDisk[256], resultsDisk[256];
	
	snprintf( testDisk, 255, "divdt_%s.dsk", argv[1]);
	snprintf( resultsDisk, 255, "divdr_%s.dsk", argv[1]);
	
	out = fopen(testDisk, "w");
	
	if( out == NULL )
	{
		fprintf( stderr, "Could not create/open %s\n", argv[1] );
		return -1;
	}
	
	printf( "Creating file: %s\n", testDisk);
	
	for( int i=0; i<17; i++ )
	{
		writeTrack(out);
	}
	
	writeTrackDirectory(out);
	
	for( int i=18; i<35; i++ )
	{
		writeTrack(out);
	}
	
	fclose( out );
	
	out = fopen(resultsDisk, "w");
	
	if( out == NULL )
	{
		fprintf( stderr, "Could not create/open %s\n", argv[1] );
		return -1;
	}
	
	printf( "Creating file: %s\n", resultsDisk);

	for( int i=0; i<35; i++ )
	{
		writeTrackFF(out);
	}

	fclose( out );
}