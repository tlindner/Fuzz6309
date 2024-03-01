#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <libkern/OSByteOrder.h>
#include <stdbool.h>

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
   3. The three code paths will have equal number of tests
   
*/

unsigned int ok_count;
unsigned int sign_overflow_count;
unsigned int range_overflow_count;

void writeSector( FILE *file )
{
	for(int i=0; i<64; i++ )
	{
		unsigned char initial_cc;
		signed short numerator;
		signed char divisor;
		
		initial_cc = random();

		initial_cc &= 0x2f; /* keep flags */
		initial_cc |= 0xd0; /* disable interrupts */
		
		bool good = false;
		signed short r;

		do
		{
			numerator = random();
			divisor = random();

			// check for zero divisor
			while( divisor == 0 )
			{
				// re-roll
				divisor = random();
			}

			r = numerator / divisor;
		
			if( r >= -128 && r <= 127 )
			{
				if( (ok_count <= sign_overflow_count) && (ok_count <= range_overflow_count))
				{
					good = true;
					ok_count++;
				}
			}
			else if( r >= -255 && r <= 255)
			{
				if( (sign_overflow_count <= ok_count) && (sign_overflow_count <= range_overflow_count))
				{
					good = true;
					sign_overflow_count++;
				}
			}
			else 
			{
				if( (range_overflow_count <= ok_count) && (range_overflow_count <= sign_overflow_count))
				{
					good = true;
					range_overflow_count++;
				}
			}
		} while (good == false);
		
		//printf( "%d / %d = %d\n", numerator, divisor, r );
		//printf( "%10d, %10d, %10d\n", ok_count, sign_overflow_count, range_overflow_count);
		
		/* Data packet for DIVD:
		 CC, A, B, divisor
		*/
		
		numerator = OSSwapInt16(numerator);
		
		fwrite( &initial_cc, 1, 1, file );
		fwrite( &numerator, 1, 2, file );
		fwrite( &divisor, 1, 1, file );
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
	ok_count = 0;
	sign_overflow_count = 0;
	range_overflow_count = 0;
	
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

	printf( "   DIVD, legal range count: %d\n", ok_count );
	printf( " DIVD, sign overflow count: %d\n", sign_overflow_count );
	printf( "DIVD, range overflow count: %d\n", range_overflow_count );
	printf( "               total count: %d\n", range_overflow_count+sign_overflow_count+ok_count );
	
}