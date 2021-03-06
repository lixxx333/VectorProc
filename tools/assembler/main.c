// 
// Copyright 2011-2012 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

#include <stdio.h>
#include <getopt.h>
#include <string.h>
#include "symbol_table.h"
#include "debug_info.h"
#include "code_output.h"

int parseSourceFile(const char *filename);

void getBasename(char *outBasename, const char *filename)
{
	const char *c = filename + strlen(filename) - 1;
	while (c > filename)
	{
		if (*c == '.')
		{
			memcpy(outBasename, filename, c - filename);
			outBasename[c - filename] = '\0';
			return;
		}
	
		c--;
	}

	strcpy(outBasename, filename);
}


int main(int argc, char *argv[])
{
	int c;
	char outputFile[256];
	char debugFilename[256];
	int index;
	int symbolDump = 0;
	
	while ((c = getopt(argc, argv, "o:s")) != -1)
	{
		switch (c)
		{
			case 'o':
				strcpy(outputFile, optarg);
				break;
				
			case 's':
				symbolDump = 1;
				break;
		}
	}

	if (outputFile == NULL)
	{
		printf("enter an output filename with -o\n");
		return 1;
	}

	if (optind == argc)
	{
		fprintf(stderr, "No source files\n");
		return 1;
	}
	
	getBasename(debugFilename, outputFile);
	strcat(debugFilename, ".dbg");
	
	enterScope();
	createSymbol("clz", SYM_KEYWORD, OP_CLZ, 1);
	createSymbol("ctz", SYM_KEYWORD, OP_CTZ, 1);
	createSymbol("ftoi", SYM_KEYWORD, OP_FTOI, 1);
	createSymbol("itof", SYM_KEYWORD, OP_ITOF, 1);
	createSymbol("floor", SYM_KEYWORD, OP_FLOOR, 1);
	createSymbol("frac", SYM_KEYWORD, OP_FRAC, 1);
	createSymbol("reciprocal", SYM_KEYWORD, OP_RECIP, 1);
	createSymbol("abs", SYM_KEYWORD, OP_ABS, 1);
	createSymbol("sqrt", SYM_KEYWORD, OP_SQRT, 1);
	createSymbol("shuffle", SYM_KEYWORD, OP_SHUFFLE, 1);
	createSymbol("getlane", SYM_KEYWORD, OP_GETLANE, 1);
	createGlobalRegisterAlias("pc", 31, 0, TYPE_UNSIGNED_INT);
	createGlobalRegisterAlias("link", 30, 0, TYPE_UNSIGNED_INT);
	createGlobalRegisterAlias("sp", 29, 0, TYPE_UNSIGNED_INT);

	if (openDebugInfo(debugFilename) < 0)
	{
		fprintf(stderr, "error opening debug file\n");
		return 1;
	}
	
	if (openOutputFile(outputFile) < 0)
	{
		fprintf(stderr, "error opening output file\n");
		return 1;
	}

	// The first instruction is a jump to the entry point.
	debugInfoSetSourceFile("start.asm");
	codeOutputSetSourceFile("start.asm");
	emitEInstruction(createSymbol("_start", SYM_LABEL, 0, 1), NULL, BRANCH_ALWAYS, 0);
	
	for (index = optind; index < argc; index++)
	{
		if (parseSourceFile(argv[index]) < 0)
			return 1;
	}
	
	if (!adjustFixups())
		return 1;
	
	closeDebugInfo();
	closeOutputFile();
	if (symbolDump)
		dumpSymbolTable();

	return 0;
}
