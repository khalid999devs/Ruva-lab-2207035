%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int yylex(void);
void yyerror(const char *s);
void yyrestart(FILE *file);

extern int yylineno;
extern FILE *yyin;
extern FILE *yyout;

double sym[26];
int visited[26];
int kind[26];
int fixed[26];
int marked[26];

int body_kind;
int body_var;
int body_left;
int body_op;
int body_right;
double body_number;
char body_text[100];

int done;
int rounds;
int is_char;
char file_name[20];

void put_text(char text[]);
void put_value(double value, int as_char);
void name_error(int x, char text[]);
void must_exist(int x);
void can_change(int x);
void mark(int x);
void declare(int t, double value, int constant);
void store(int x, double value);
void read_value(int x);
double calc(double a, int op, double b);
double power(double a, double b);
void run_body(void);
void loop_round(void);
%}

%union {
    int index;
    double value;
    char text[100];
}

%token <index> VAR
%token <value> NUMBER CHARACTER
%token <text> STRING ID
%token LAUNCH KEEP VARY INT REAL CHAR CHECK OTHERWISE WALK FROM UNTIL DURING
%token CRAFT GIVE VOID SHOW ASK EQ NE LE GE DEC ARROW

%type <value> expr value
%type <index> type op rel
%type <text> name

%left EQ NE
%left '<' '>' LE GE
%left '+' '-'
%left '*' '/' '%'
%left NEG
%right '^'

%%

program:
        items
        | items LAUNCH '{' statements '}'
        ;

items:
        /* empty */
        | items declaration
        | items function
        ;

statements:
        /* empty */
        | statements statement
        ;

statement:
        declaration
        | VAR '=' expr ';'                          {
                                                        can_change($1);
                                                        store($1, $3);
                                                    }
        | SHOW '(' expr ')' ';'                     {
                                                        put_value($3, is_char);
                                                        put_text("\n");
                                                    }
        | SHOW '(' STRING ')' ';'                   {
                                                        put_text($3);
                                                        put_text("\n");
                                                    }
        | SHOW '(' STRING ',' expr ')' ';'          {
                                                        put_text($3);
                                                        put_text(" ");
                                                        put_value($5, is_char);
                                                        put_text("\n");
                                                    }
        | ASK '(' VAR ')' ';'                       { read_value($3); }
        | ASK '(' STRING ',' VAR ')' ';'            {
                                                        put_text($3);
                                                        put_text(" ");
                                                        read_value($5);
                                                    }
        | condition
        | walk_loop
        | during_loop
        | name '(' args ')' ';'                     {
                                                        put_text("Call to ");
                                                        put_text($1);
                                                        put_text(" found\n");
                                                    }
        ;

declaration:
        VARY names ':' type ';'                     { declare($4, 0, 0); }
        | VARY names ':' type '=' expr ';'          { declare($4, $6, 0); }
        | KEEP names ':' type '=' expr ';'          { declare($4, $6, 1); }
        ;

names:
        VAR                                         { mark($1); }
        | names ',' VAR                             { mark($3); }
        ;

type:
        INT                                         { $$ = INT; }
        | REAL                                      { $$ = REAL; }
        | CHAR                                      { $$ = CHAR; }
        ;

condition:
        if_part else_ifs else_part
        ;

if_part:
        CHECK expr '{' body '}'                     {
                                                        done = ($2 != 0);

                                                        if (done)
                                                            run_body();
                                                    }
        ;

else_ifs:
        /* empty */
        | else_ifs OTHERWISE CHECK expr '{' body '}'
                                                    {
                                                        if (!done && $4 != 0) {
                                                            done = 1;
                                                            run_body();
                                                        }
                                                    }
        ;

else_part:
        /* empty */
        | OTHERWISE '{' body '}'                    {
                                                        if (!done)
                                                            run_body();
                                                    }
        ;

walk_loop:
        WALK VAR FROM expr UNTIL expr '{' body '}'  {
                                                        can_change($2);
                                                        rounds = 0;

                                                        for (sym[$2] = $4; sym[$2] < $6; sym[$2]++)
                                                            loop_round();
                                                    }
        ;

during_loop:
        DURING VAR rel value '{' body '}'           {
                                                        must_exist($2);
                                                        rounds = 0;

                                                        while (calc(sym[$2], $3, $4))
                                                            loop_round();
                                                    }
        | DURING VAR rel VAR '{' body '}'           {
                                                        must_exist($2);
                                                        must_exist($4);
                                                        rounds = 0;

                                                        while (calc(sym[$2], $3, sym[$4]))
                                                            loop_round();
                                                    }
        | DURING VAR DEC '{' body '}'               {
                                                        can_change($2);
                                                        rounds = 0;

                                                        while (sym[$2]--)
                                                            loop_round();
                                                    }
        ;

body:
        SHOW '(' STRING ')' ';'                     {
                                                        body_kind = 1;
                                                        strcpy(body_text, $3);
                                                    }
        | SHOW '(' VAR ')' ';'                      {
                                                        must_exist($3);
                                                        body_kind = 2;
                                                        body_var = $3;
                                                    }
        | SHOW '(' STRING ',' VAR ')' ';'           {
                                                        must_exist($5);
                                                        body_kind = 3;
                                                        strcpy(body_text, $3);
                                                        body_var = $5;
                                                    }
        | VAR '=' value ';'                         {
                                                        can_change($1);
                                                        body_kind = 4;
                                                        body_var = $1;
                                                        body_number = $3;
                                                    }
        | VAR '=' VAR op value ';'                  {
                                                        can_change($1);
                                                        must_exist($3);
                                                        body_kind = 5;
                                                        body_var = $1;
                                                        body_left = $3;
                                                        body_op = $4;
                                                        body_number = $5;
                                                    }
        | VAR '=' VAR op VAR ';'                    {
                                                        can_change($1);
                                                        must_exist($3);
                                                        must_exist($5);
                                                        body_kind = 6;
                                                        body_var = $1;
                                                        body_left = $3;
                                                        body_op = $4;
                                                        body_right = $5;
                                                    }
        ;

value:
        NUMBER
        | CHARACTER
        ;

op:
        '+'                                         { $$ = '+'; }
        | '-'                                       { $$ = '-'; }
        | '*'                                       { $$ = '*'; }
        | '/'                                       { $$ = '/'; }
        | '%'                                       { $$ = '%'; }
        ;

rel:
        EQ                                          { $$ = EQ; }
        | NE                                        { $$ = NE; }
        | '<'                                       { $$ = '<'; }
        | '>'                                       { $$ = '>'; }
        | LE                                        { $$ = LE; }
        | GE                                        { $$ = GE; }
        ;

expr:
        NUMBER                                      { $$ = $1; is_char = 0; }
        | CHARACTER                                 { $$ = $1; is_char = 1; }
        | VAR                                       {
                                                        must_exist($1);
                                                        $$ = sym[$1];
                                                        is_char = (kind[$1] == CHAR);
                                                    }
        | expr '+' expr                             { $$ = calc($1, '+', $3); }
        | expr '-' expr                             { $$ = calc($1, '-', $3); }
        | expr '*' expr                             { $$ = calc($1, '*', $3); }
        | expr '/' expr                             { $$ = calc($1, '/', $3); }
        | expr '%' expr                             { $$ = calc($1, '%', $3); }
        | expr '^' expr                             { $$ = calc($1, '^', $3); }
        | expr EQ expr                              { $$ = calc($1, EQ, $3); }
        | expr NE expr                              { $$ = calc($1, NE, $3); }
        | expr '<' expr                             { $$ = calc($1, '<', $3); }
        | expr '>' expr                             { $$ = calc($1, '>', $3); }
        | expr LE expr                              { $$ = calc($1, LE, $3); }
        | expr GE expr                              { $$ = calc($1, GE, $3); }
        | '-' expr %prec NEG                        { $$ = -$2; is_char = 0; }
        | '(' expr ')'                              { $$ = $2; }
        ;

function:
        CRAFT name '(' params ')' ARROW result '{' code '}'
                                                    {
                                                        put_text("Function ");
                                                        put_text($2);
                                                        put_text(" found\n");
                                                    }
        ;

name:
        ID                                          { strcpy($$, $1); }
        | VAR                                       {
                                                        $$[0] = 'a' + $1;
                                                        $$[1] = '\0';
                                                    }
        ;

params:
        /* empty */
        | param_list
        ;

param_list:
        param
        | param_list ',' param
        ;

param:
        name ':' type
        ;

result:
        type
        | VOID
        ;

code:
        /* empty */
        | code piece
        ;

piece:
        VAR | ID | NUMBER | CHARACTER | STRING
        | GIVE | VARY | KEEP | INT | REAL | CHAR | SHOW | ASK
        | EQ | NE | LE | GE
        | '+' | '-' | '*' | '/' | '%' | '^' | '<' | '>' | '='
        | '(' | ')' | ',' | ':' | ';'
        ;

args:
        /* empty */
        | arg_list
        ;

arg_list:
        arg
        | arg_list ',' arg
        ;

arg:
        VAR | ID | NUMBER | CHARACTER | STRING
        ;

%%

void put_text(char text[])
{
    printf("%s", text);
    fprintf(yyout, "%s", text);
}

void put_value(double value, int as_char)
{
    if (as_char) {
        printf("%c", (int) value);
        fprintf(yyout, "%c", (int) value);
    } else {
        printf("%.10g", value);
        fprintf(yyout, "%.10g", value);
    }
}

void yyerror(const char *s)
{
    printf("Error in %s at line %d: %s\n", file_name, yylineno, s);
    fprintf(yyout, "Error in %s at line %d: %s\n", file_name, yylineno, s);
    fclose(yyout);
    exit(1);
}

void name_error(int x, char text[])
{
    char message[100];

    sprintf(message, "%c %s", 'a' + x, text);
    yyerror(message);
}

void must_exist(int x)
{
    if (!visited[x])
        name_error(x, "is not declared");
}

void can_change(int x)
{
    must_exist(x);

    if (fixed[x])
        name_error(x, "is a constant and cannot be changed");
}

void mark(int x)
{
    if (visited[x] || marked[x])
        name_error(x, "is already declared");

    marked[x] = 1;
}

void declare(int t, double value, int constant)
{
    int i;

    for (i = 0; i < 26; i++) {
        if (marked[i]) {
            visited[i] = 1;
            kind[i] = t;
            fixed[i] = constant;

            store(i, value);
            marked[i] = 0;
        }
    }
}

void store(int x, double value)
{
    if (kind[x] == REAL)
        sym[x] = value;
    else
        sym[x] = (int) value;
}

void read_value(int x)
{
    double number;
    char letter;

    can_change(x);
    fflush(stdout);

    if (kind[x] == CHAR) {
        if (scanf(" %c", &letter) != 1)
            name_error(x, "needs a character as input");

        number = letter;

    } else {
        if (scanf("%lf", &number) != 1)
            name_error(x, "needs a number as input");
    }

    store(x, number);

    if (kind[x] == CHAR)
        fprintf(yyout, "%c\n", (int) sym[x]);
    else
        fprintf(yyout, "%.10g\n", sym[x]);
}

double calc(double a, int op, double b)
{
    is_char = 0;

    if (op == '+')
        return a + b;

    if (op == '-')
        return a - b;

    if (op == '*')
        return a * b;

    if (op == '/') {
        if (b == 0)
            yyerror("division by zero");

        return a / b;
    }

    if (op == '%') {
        if ((int) b == 0)
            yyerror("division by zero");

        return (int) a % (int) b;
    }

    if (op == '^')
        return power(a, b);

    if (op == EQ)
        return a == b;

    if (op == NE)
        return a != b;

    if (op == '<')
        return a < b;

    if (op == '>')
        return a > b;

    if (op == LE)
        return a <= b;

    return a >= b;
}

double power(double a, double b)
{
    double result = 1;
    int n = (int) b;
    int i;

    if (n < 0)
        n = -n;

    for (i = 0; i < n; i++)
        result = result * a;

    if (b < 0)
        return 1 / result;

    return result;
}

void run_body(void)
{
    if (body_kind == 1) {
        put_text(body_text);
        put_text("\n");
    } else if (body_kind == 2) {
        put_value(sym[body_var], kind[body_var] == CHAR);
        put_text("\n");
    } else if (body_kind == 3) {
        put_text(body_text);
        put_text(" ");
        put_value(sym[body_var], kind[body_var] == CHAR);
        put_text("\n");
    } else if (body_kind == 4) {
        store(body_var, body_number);
    } else if (body_kind == 5) {
        store(body_var, calc(sym[body_left], body_op, body_number));
    } else {
        store(body_var, calc(sym[body_left], body_op, sym[body_right]));
    }
}

void loop_round(void)
{
    rounds++;

    if (rounds > 1000)
        yyerror("loop stopped after 1000 rounds");

    run_body();
}

int main(void)
{
    FILE *module;

    yyout = fopen("output.txt", "w");

    if (yyout == NULL) {
        printf("cannot create output.txt\n");
        return 1;
    }
    module = fopen("module.txt", "r");

    if (module != NULL) {
        strcpy(file_name, "module.txt");
        yylineno = 1;
        yyrestart(module);
        yyparse();
        fclose(module);
    }

    yyin = fopen("input.txt", "r");

    if (yyin == NULL) {
        printf("input.txt not found\n");
        fclose(yyout);
        return 1;
    }

    strcpy(file_name, "input.txt");
    yylineno = 1;
    
    yyrestart(yyin);
    yyparse();

    fclose(yyout);
    return 0;
}
