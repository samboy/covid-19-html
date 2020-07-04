// Public domain 2020 Sam Trenholme
#include <stdio.h>

// Take a quoted CSV table from standard input, and remove quotes and any
// commas in the quotes
int main() {
	int state = 0;
	int i = 0;
	while(!feof(stdin)) {
		i = getc(stdin);
		if(i == '"') { state ^= 1; }
		else if(state == 0 || i != ',') {printf("%c",i);}
	}
	return 0;
}
