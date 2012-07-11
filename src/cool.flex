%option c++
%option noyywrap
%option yylineno

%{

#include "tokens.hpp"
#include "tokentable.hpp"
#include "symboltable.hpp"
// #include "y.tab.h"

static const int MAX_STR_CONST = 1025;

extern IdentifierTable idtable;
extern IntTable inttable;
extern StringTable stringtable;

char string_buf[MAX_STR_CONST];  // buffer to store string contstants encountered in source file
char *string_buf_ptr;

size_t num_comment = 0;      // count to keep track how many opening comment tokens have been encountered
size_t curr_lineno = 0;      // keep track of current line number of source file
bool str_too_long = false;   // used to handle string constant size error check

extern YYSTYPE yylval;

%}

%x COMMENT
%x LINECOMMENT
%x STRING

DARROW =>

%%

"(*" {
    BEGIN(COMMENT);
    num_comment++;
}

"*)" {
    if (num_comment <= 0) {
        yylval.error_msg = "Unmatched *)";
        return ERROR;
    }
}

<COMMENT>"*)" {
    num_comment--;
    if (num_comment < 0) {
        yylval.error_msg = "Unmatched *)";
        return ERROR;
    }

    if (num_comment == 0) {
        BEGIN(INITIAL);
    }
}

<COMMENT>"(*" {
    num_comment++;
}

<COMMENT>[^\n] {
    // eat everything within comments
}

<COMMENT>\n {
    ++curr_lineno;
}

"--"[^\n]* {
    BEGIN(LINECOMMENT);
}

<LINECOMMENT>\n {
    ++curr_lineno;
    BEGIN(INITIAL);
}

<COMMENT><<EOF>> {
    BEGIN(INITIAL);
    yylval.error_msg = "EOF in comment";
    return ERROR;
}

"=>" {
    return DARROW; 
}

(?i:class) {
    return CLASS;
}

(?i:else) {
    return ELSE;
}

(?i:in) {
    return IN;
}

(?i:then) {
    return THEN;
}

(?i:fi) {
    return FI;
}

(?i:if) {
    return IF;
}

(?i:inherits) {
    return INHERITS;
}

(?i:let) {
    return LET;
}

(?i:loop) {
    return LOOP;
}

(?i:pool) {
    return POOL;
}

(?i:while) {
    return WHILE;
}

(?i:case) {
    return CASE;
}

(?i:esac) {
    return ESAC;
}

(?i:of) {
    return OF;
}

(?i:new) {
    return NEW;
}

(?i:isvoid) {
    return ISVOID;
}

(?i:not) {
    return NOT;
}

t(?i:rue) {
    yylval.boolean = true;
    return BOOL_CONST;
}

f(?i:alse) {
    yylval.boolean = false;
    return BOOL_CONST;
}

[0-9]+ {
    yylval.int_const = YYText();
    return INT_CONST;
}

"<=" {
    return LE;
}

"<-" {
    return ASSIGN;
}


[A-Z][a-zA-Z0-9_]* {
    yylval.id = YYText();
    return TYPEID;
}


[a-z][a-zA-Z0-9_]* {
    yylval.id = YYText();
    return OBJECTID;
}

";"|","|"{"|"}"|":"|"("|")"|"+"|"-"|"*"|"/"|"="|"~"|"<"|"."|"@" {
    return *YYText();
}

\n {
    ++curr_lineno;
}

[ \f\r\t\v] {
    // eat whitespace
}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */

\" {
    BEGIN(STRING);
    string_buf_ptr = string_buf;
    memset(string_buf, 0, MAX_STR_CONST);
}

<STRING>\" {
    BEGIN(INITIAL);
    yylval.str_const = string_buf;
    return STR_CONST;
}

<STRING>\0[^\n]*\" {
    BEGIN(INITIAL);
    if (str_too_long) {
        str_too_long = false;
    }
    else {
        yylval.error_msg = "String contains null character";
        return ERROR;
    }
}

<STRING>\0[^"]*\n {
    if (str_too_long) {
        yyinput(); /* eat quote */
        BEGIN(INITIAL);
        str_too_long = false;
    }
    else {
        if (YYText()[YYLeng() - 1] != '\\') {
            BEGIN(INITIAL);
            yylval.error_msg = "String contains null character";
            return ERROR;
        }
    }
}

<STRING><<EOF>> {
    BEGIN(INITIAL);
    yylval.error_msg = "EOF in string constant";
    return ERROR;
}

<STRING>\\ {
    if (strlen(string_buf) >= MAX_STR_CONST - 1) {
        str_too_long = true;
        unput('\0');
        yylval.error_msg = "String constant too long";
        return ERROR;
    }

    char ahead = yyinput();
    switch (ahead) {
        case 'b':
            *string_buf_ptr++ = '\b';
            break;
        case 't':
            *string_buf_ptr++ = '\t';
            break;
        case 'n':
            *string_buf_ptr++ = '\n';
            break;
        case 'f':
            *string_buf_ptr++ = '\f';
            break;
        case '\n':
            ++curr_lineno;
            *string_buf_ptr++ = '\n';
            break;
        case '\0':
            unput(ahead);
            break;
        default:
            *string_buf_ptr++ = ahead;
    }
}

<STRING>\n {
    ++curr_lineno;
    BEGIN(INITIAL);
    yylval.error_msg = "Unterminated string constant";
    return ERROR;
}

<STRING>. {
    if (strlen(string_buf) >= MAX_STR_CONST - 1) {
        str_too_long = true;
        unput('\0');
        yylval.error_msg = "String constant too long";
        return ERROR;
    }

    *string_buf_ptr++ = *YYText();
}
    
. /* error for invalid tokens */ {
    yylval.error_msg = YYText();
    return ERROR;
}

%%
