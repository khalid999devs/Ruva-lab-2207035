%option noyywrap
%option yylineno

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ruva.tab.h"

void yyerror(const char *s);
void read_text(void);
%}

DIGIT       [0-9]
ID          [A-Za-z_][A-Za-z0-9_]*

%x COMMENT

%%

[ \t\r\n]+              ;
"//".*                  ;

"/*"                    { BEGIN(COMMENT); }
<COMMENT>"*/"           { BEGIN(INITIAL); }
<COMMENT>\n             ;
<COMMENT>.              ;

"launch"                { return LAUNCH; }
"keep"                  { return KEEP; }
"vary"                  { return VARY; }
"int"                   { return INT; }
"real"                  { return REAL; }
"char"                  { return CHAR; }
"check"                 { return CHECK; }
"otherwise"             { return OTHERWISE; }
"walk"                  { return WALK; }
"from"                  { return FROM; }
"until"                 { return UNTIL; }
"during"                { return DURING; }
"craft"                 { return CRAFT; }
"give"                  { return GIVE; }
"void"                  { return VOID; }
"show"                  { return SHOW; }
"ask"                   { return ASK; }

[a-z]                   {
                            yylval.index = yytext[0] - 'a';
                            return VAR;
                        }

{ID}                    {
                            if (yyleng > 99)
                                yyerror("name is too long");

                            strcpy(yylval.text, yytext);
                            return ID;
                        }

{DIGIT}+"."{DIGIT}+     {
                            yylval.value = atof(yytext);
                            return NUMBER;
                        }

{DIGIT}+                {
                            yylval.value = atoi(yytext);
                            return NUMBER;
                        }

'[^'\\\n]'              {
                            yylval.value = yytext[1];
                            return CHARACTER;
                        }

\"([^"\\\n]|\\.)*\"     {
                            read_text();
                            return STRING;
                        }

\"[^"\n]*               { yyerror("text is not closed"); }

"=="                    { return EQ; }
"!="                    { return NE; }
"<="                    { return LE; }
">="                    { return GE; }
"--"                    { return DEC; }
"->"                    { return ARROW; }

[-+*/%^<>=(){},:;]      { return yytext[0]; }

.                       { yyerror("unknown character"); }

%%

void read_text(void)
{
    int i;
    int n = 0;

    if (yyleng > 100)
        yyerror("text is too long");

    for (i = 1; i < yyleng - 1; i++) {
        if (yytext[i] == '\\') {
            i++;

            if (yytext[i] == 'n')
                yylval.text[n] = '\n';
            else if (yytext[i] == 't')
                yylval.text[n] = '\t';
            else
                yylval.text[n] = yytext[i];
        } else {
            yylval.text[n] = yytext[i];
        }

        n++;
    }

    yylval.text[n] = '\0';
}
