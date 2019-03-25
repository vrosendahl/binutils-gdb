/* YACC grammar for Modula-2 expressions, for GDB.
   Copyright (C) 1986-2019 Free Software Foundation, Inc.
   Generated from expread.y (now c-exp.y) and contributed by the Department
   of Computer Science at the State University of New York at Buffalo, 1991.

   This file is part of GDB.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Parse a Modula-2 expression from text in a string,
   and return the result as a  struct expression  pointer.
   That structure contains arithmetic operations in reverse polish,
   with constants represented by operations that are followed by special data.
   See expression.h for the details of the format.
   What is important here is that it can be built up sequentially
   during the process of parsing; the lower levels of the tree always
   come first in the result.

   Note that malloc's and realloc's in this file are transformed to
   xmalloc and xrealloc respectively by the same sed command in the
   makefile that remaps any other malloc/realloc inserted by the parser
   generator.  Doing this with #defines and trying to control the interaction
   with include files (<malloc.h> and <stdlib.h> for example) just became
   too messy, particularly when such includes can be inserted at random
   times by the parser generator.  */
   
%{

#include "defs.h"
#include "expression.h"
#include "language.h"
#include "value.h"
#include "parser-defs.h"
#include "m2-lang.h"
#include "bfd.h" /* Required by objfiles.h.  */
#include "symfile.h" /* Required by objfiles.h.  */
#include "objfiles.h" /* For have_full_symbols and have_partial_symbols */
#include "block.h"

#define parse_type(ps) builtin_type (ps->gdbarch ())
#define parse_m2_type(ps) builtin_m2_type (ps->gdbarch ())

/* Remap normal yacc parser interface names (yyparse, yylex, yyerror,
   etc).  */
#define GDB_YY_REMAP_PREFIX m2_
#include "yy-remap.h"

/* The state of the parser, used internally when we are parsing the
   expression.  */

static struct parser_state *pstate = NULL;

int yyparse (void);

static int yylex (void);

static void yyerror (const char *);

static int parse_number (int);

/* The sign of the number being parsed.  */
static int number_sign = 1;

%}

/* Although the yacc "value" of an expression is not used,
   since the result is stored in the structure being created,
   other node types do have values.  */

%union
  {
    LONGEST lval;
    ULONGEST ulval;
    gdb_byte val[16];
    struct symbol *sym;
    struct type *tval;
    struct stoken sval;
    int voidval;
    const struct block *bval;
    enum exp_opcode opcode;
    struct internalvar *ivar;

    struct type **tvec;
    int *ivec;
  }

%type <voidval> exp type_exp start set
%type <voidval> variable
%type <tval> type
%type <bval> block 
%type <sym> fblock 

%token <lval> INT HEX ERROR
%token <ulval> UINT M2_TRUE M2_FALSE CHAR
%token <val> FLOAT

/* Both NAME and TYPENAME tokens represent symbols in the input,
   and both convey their data as strings.
   But a TYPENAME is a string that happens to be defined as a typedef
   or builtin type name (such as int or char)
   and a NAME is any other symbol.

   Contexts where this distinction is not important can use the
   nonterminal "name", which matches either NAME or TYPENAME.  */

%token <sval> STRING
%token <sval> NAME BLOCKNAME IDENT VARNAME
%token <sval> TYPENAME

%token SIZE CAP ORD HIGH ABS MIN_FUNC MAX_FUNC FLOAT_FUNC VAL CHR ODD TRUNC
%token TSIZE
%token INC DEC INCL EXCL

/* The GDB scope operator */
%token COLONCOLON

%token <voidval> DOLLAR_VARIABLE

/* M2 tokens */
%left ','
%left ABOVE_COMMA
%nonassoc ASSIGN
%left '<' '>' LEQ GEQ '=' NOTEQUAL '#' IN
%left OROR
%left LOGICAL_AND '&'
%left '@'
%left '+' '-'
%left '*' '/' DIV MOD
%right UNARY
%right '^' DOT '[' '('
%right NOT '~'
%left COLONCOLON QID
/* This is not an actual token ; it is used for precedence. 
%right QID
*/


%%

start   :	exp
	|	type_exp
	;

type_exp:	type
		{ write_exp_elt_opcode (pstate, OP_TYPE);
		  write_exp_elt_type (pstate, $1);
		  write_exp_elt_opcode (pstate, OP_TYPE);
		}
	;

/* Expressions */

exp     :       exp '^'   %prec UNARY
                        { write_exp_elt_opcode (pstate, UNOP_IND); }
	;

exp	:	'-'
			{ number_sign = -1; }
		exp    %prec UNARY
			{ number_sign = 1;
			  write_exp_elt_opcode (pstate, UNOP_NEG); }
	;

exp	:	'+' exp    %prec UNARY
		{ write_exp_elt_opcode (pstate, UNOP_PLUS); }
	;

exp	:	not_exp exp %prec UNARY
			{ write_exp_elt_opcode (pstate, UNOP_LOGICAL_NOT); }
	;

not_exp	:	NOT
	|	'~'
	;

exp	:	CAP '(' exp ')'
			{ write_exp_elt_opcode (pstate, UNOP_CAP); }
	;

exp	:	ORD '(' exp ')'
			{ write_exp_elt_opcode (pstate, UNOP_ORD); }
	;

exp	:	ABS '(' exp ')'
			{ write_exp_elt_opcode (pstate, UNOP_ABS); }
	;

exp	: 	HIGH '(' exp ')'
			{ write_exp_elt_opcode (pstate, UNOP_HIGH); }
	;

exp 	:	MIN_FUNC '(' type ')'
			{ write_exp_elt_opcode (pstate, UNOP_MIN);
			  write_exp_elt_type (pstate, $3);
			  write_exp_elt_opcode (pstate, UNOP_MIN); }
	;

exp	: 	MAX_FUNC '(' type ')'
			{ write_exp_elt_opcode (pstate, UNOP_MAX);
			  write_exp_elt_type (pstate, $3);
			  write_exp_elt_opcode (pstate, UNOP_MAX); }
	;

exp	:	FLOAT_FUNC '(' exp ')'
			{ write_exp_elt_opcode (pstate, UNOP_FLOAT); }
	;

exp	:	VAL '(' type ',' exp ')'
			{ write_exp_elt_opcode (pstate, BINOP_VAL);
			  write_exp_elt_type (pstate, $3);
			  write_exp_elt_opcode (pstate, BINOP_VAL); }
	;

exp	:	CHR '(' exp ')'
			{ write_exp_elt_opcode (pstate, UNOP_CHR); }
	;

exp	:	ODD '(' exp ')'
			{ write_exp_elt_opcode (pstate, UNOP_ODD); }
	;

exp	:	TRUNC '(' exp ')'
			{ write_exp_elt_opcode (pstate, UNOP_TRUNC); }
	;

exp	:	TSIZE '(' exp ')'
			{ write_exp_elt_opcode (pstate, UNOP_SIZEOF); }
	;

exp	:	SIZE exp       %prec UNARY
			{ write_exp_elt_opcode (pstate, UNOP_SIZEOF); }
	;


exp	:	INC '(' exp ')'
			{ write_exp_elt_opcode (pstate, UNOP_PREINCREMENT); }
	;

exp	:	INC '(' exp ',' exp ')'
			{ write_exp_elt_opcode (pstate, BINOP_ASSIGN_MODIFY);
			  write_exp_elt_opcode (pstate, BINOP_ADD);
			  write_exp_elt_opcode (pstate,
						BINOP_ASSIGN_MODIFY); }
	;

exp	:	DEC '(' exp ')'
			{ write_exp_elt_opcode (pstate, UNOP_PREDECREMENT);}
	;

exp	:	DEC '(' exp ',' exp ')'
			{ write_exp_elt_opcode (pstate, BINOP_ASSIGN_MODIFY);
			  write_exp_elt_opcode (pstate, BINOP_SUB);
			  write_exp_elt_opcode (pstate,
						BINOP_ASSIGN_MODIFY); }
	;

exp	:	exp DOT NAME
			{ write_exp_elt_opcode (pstate, STRUCTOP_STRUCT);
			  write_exp_string (pstate, $3);
			  write_exp_elt_opcode (pstate, STRUCTOP_STRUCT); }
	;

exp	:	set
	;

exp	:	exp IN set
			{ error (_("Sets are not implemented."));}
	;

exp	:	INCL '(' exp ',' exp ')'
			{ error (_("Sets are not implemented."));}
	;

exp	:	EXCL '(' exp ',' exp ')'
			{ error (_("Sets are not implemented."));}
	;

set	:	'{' arglist '}'
			{ error (_("Sets are not implemented."));}
	|	type '{' arglist '}'
			{ error (_("Sets are not implemented."));}
	;


/* Modula-2 array subscript notation [a,b,c...] */
exp     :       exp '['
                        /* This function just saves the number of arguments
			   that follow in the list.  It is *not* specific to
			   function types */
                        { pstate->start_arglist(); }
                non_empty_arglist ']'  %prec DOT
                        { write_exp_elt_opcode (pstate, MULTI_SUBSCRIPT);
			  write_exp_elt_longcst (pstate,
						 pstate->end_arglist());
			  write_exp_elt_opcode (pstate, MULTI_SUBSCRIPT); }
        ;

exp	:	exp '[' exp ']'
			{ write_exp_elt_opcode (pstate, BINOP_SUBSCRIPT); }
	;

exp	:	exp '('
			/* This is to save the value of arglist_len
			   being accumulated by an outer function call.  */
			{ pstate->start_arglist (); }
		arglist ')'	%prec DOT
			{ write_exp_elt_opcode (pstate, OP_FUNCALL);
			  write_exp_elt_longcst (pstate,
						 pstate->end_arglist ());
			  write_exp_elt_opcode (pstate, OP_FUNCALL); }
	;

arglist	:
	;

arglist	:	exp
			{ pstate->arglist_len = 1; }
	;

arglist	:	arglist ',' exp   %prec ABOVE_COMMA
			{ pstate->arglist_len++; }
	;

non_empty_arglist
        :       exp
                        { pstate->arglist_len = 1; }
	;

non_empty_arglist
        :       non_empty_arglist ',' exp %prec ABOVE_COMMA
     	       	    	{ pstate->arglist_len++; }
     	;

/* GDB construct */
exp	:	'{' type '}' exp  %prec UNARY
			{ write_exp_elt_opcode (pstate, UNOP_MEMVAL);
			  write_exp_elt_type (pstate, $2);
			  write_exp_elt_opcode (pstate, UNOP_MEMVAL); }
	;

exp     :       type '(' exp ')' %prec UNARY
                        { write_exp_elt_opcode (pstate, UNOP_CAST);
			  write_exp_elt_type (pstate, $1);
			  write_exp_elt_opcode (pstate, UNOP_CAST); }
	;

exp	:	'(' exp ')'
			{ }
	;

/* Binary operators in order of decreasing precedence.  Note that some
   of these operators are overloaded!  (ie. sets) */

/* GDB construct */
exp	:	exp '@' exp
			{ write_exp_elt_opcode (pstate, BINOP_REPEAT); }
	;

exp	:	exp '*' exp
			{ write_exp_elt_opcode (pstate, BINOP_MUL); }
	;

exp	:	exp '/' exp
			{ write_exp_elt_opcode (pstate, BINOP_DIV); }
	;

exp     :       exp DIV exp
                        { write_exp_elt_opcode (pstate, BINOP_INTDIV); }
        ;

exp	:	exp MOD exp
			{ write_exp_elt_opcode (pstate, BINOP_REM); }
	;

exp	:	exp '+' exp
			{ write_exp_elt_opcode (pstate, BINOP_ADD); }
	;

exp	:	exp '-' exp
			{ write_exp_elt_opcode (pstate, BINOP_SUB); }
	;

exp	:	exp '=' exp
			{ write_exp_elt_opcode (pstate, BINOP_EQUAL); }
	;

exp	:	exp NOTEQUAL exp
			{ write_exp_elt_opcode (pstate, BINOP_NOTEQUAL); }
        |       exp '#' exp
                        { write_exp_elt_opcode (pstate, BINOP_NOTEQUAL); }
	;

exp	:	exp LEQ exp
			{ write_exp_elt_opcode (pstate, BINOP_LEQ); }
	;

exp	:	exp GEQ exp
			{ write_exp_elt_opcode (pstate, BINOP_GEQ); }
	;

exp	:	exp '<' exp
			{ write_exp_elt_opcode (pstate, BINOP_LESS); }
	;

exp	:	exp '>' exp
			{ write_exp_elt_opcode (pstate, BINOP_GTR); }
	;

exp	:	exp LOGICAL_AND exp
			{ write_exp_elt_opcode (pstate, BINOP_LOGICAL_AND); }
	;

exp	:	exp OROR exp
			{ write_exp_elt_opcode (pstate, BINOP_LOGICAL_OR); }
	;

exp	:	exp ASSIGN exp
			{ write_exp_elt_opcode (pstate, BINOP_ASSIGN); }
	;


/* Constants */

exp	:	M2_TRUE
			{ write_exp_elt_opcode (pstate, OP_BOOL);
			  write_exp_elt_longcst (pstate, (LONGEST) $1);
			  write_exp_elt_opcode (pstate, OP_BOOL); }
	;

exp	:	M2_FALSE
			{ write_exp_elt_opcode (pstate, OP_BOOL);
			  write_exp_elt_longcst (pstate, (LONGEST) $1);
			  write_exp_elt_opcode (pstate, OP_BOOL); }
	;

exp	:	INT
			{ write_exp_elt_opcode (pstate, OP_LONG);
			  write_exp_elt_type (pstate,
					parse_m2_type (pstate)->builtin_int);
			  write_exp_elt_longcst (pstate, (LONGEST) $1);
			  write_exp_elt_opcode (pstate, OP_LONG); }
	;

exp	:	UINT
			{
			  write_exp_elt_opcode (pstate, OP_LONG);
			  write_exp_elt_type (pstate,
					      parse_m2_type (pstate)
					      ->builtin_card);
			  write_exp_elt_longcst (pstate, (LONGEST) $1);
			  write_exp_elt_opcode (pstate, OP_LONG);
			}
	;

exp	:	CHAR
			{ write_exp_elt_opcode (pstate, OP_LONG);
			  write_exp_elt_type (pstate,
					      parse_m2_type (pstate)
					      ->builtin_char);
			  write_exp_elt_longcst (pstate, (LONGEST) $1);
			  write_exp_elt_opcode (pstate, OP_LONG); }
	;


exp	:	FLOAT
			{ write_exp_elt_opcode (pstate, OP_FLOAT);
			  write_exp_elt_type (pstate,
					      parse_m2_type (pstate)
					      ->builtin_real);
			  write_exp_elt_floatcst (pstate, $1);
			  write_exp_elt_opcode (pstate, OP_FLOAT); }
	;

exp	:	variable
	;

exp	:	SIZE '(' type ')'	%prec UNARY
			{ write_exp_elt_opcode (pstate, OP_LONG);
			  write_exp_elt_type (pstate,
					    parse_type (pstate)->builtin_int);
			  write_exp_elt_longcst (pstate,
						 (LONGEST) TYPE_LENGTH ($3));
			  write_exp_elt_opcode (pstate, OP_LONG); }
	;

exp	:	STRING
			{ write_exp_elt_opcode (pstate, OP_M2_STRING);
			  write_exp_string (pstate, $1);
			  write_exp_elt_opcode (pstate, OP_M2_STRING); }
	;

/* This will be used for extensions later.  Like adding modules.  */
block	:	fblock	
			{ $$ = SYMBOL_BLOCK_VALUE($1); }
	;

fblock	:	BLOCKNAME
			{ struct symbol *sym
			    = lookup_symbol (copy_name ($1),
					     pstate->expression_context_block,
					     VAR_DOMAIN, 0).symbol;
			  $$ = sym;}
	;
			     

/* GDB scope operator */
fblock	:	block COLONCOLON BLOCKNAME
			{ struct symbol *tem
			    = lookup_symbol (copy_name ($3), $1,
					     VAR_DOMAIN, 0).symbol;
			  if (!tem || SYMBOL_CLASS (tem) != LOC_BLOCK)
			    error (_("No function \"%s\" in specified context."),
				   copy_name ($3));
			  $$ = tem;
			}
	;

/* Useful for assigning to PROCEDURE variables */
variable:	fblock
			{ write_exp_elt_opcode (pstate, OP_VAR_VALUE);
			  write_exp_elt_block (pstate, NULL);
			  write_exp_elt_sym (pstate, $1);
			  write_exp_elt_opcode (pstate, OP_VAR_VALUE); }
	;

/* GDB internal ($foo) variable */
variable:	DOLLAR_VARIABLE
	;

/* GDB scope operator */
variable:	block COLONCOLON NAME
			{ struct block_symbol sym
			    = lookup_symbol (copy_name ($3), $1,
					     VAR_DOMAIN, 0);

			  if (sym.symbol == 0)
			    error (_("No symbol \"%s\" in specified context."),
				   copy_name ($3));
			  if (symbol_read_needs_frame (sym.symbol))
			    innermost_block.update (sym);

			  write_exp_elt_opcode (pstate, OP_VAR_VALUE);
			  write_exp_elt_block (pstate, sym.block);
			  write_exp_elt_sym (pstate, sym.symbol);
			  write_exp_elt_opcode (pstate, OP_VAR_VALUE); }
	;

/* Base case for variables.  */
variable:	NAME
			{ struct block_symbol sym;
			  struct field_of_this_result is_a_field_of_this;

			  sym
			    = lookup_symbol (copy_name ($1),
					     pstate->expression_context_block,
					     VAR_DOMAIN,
					     &is_a_field_of_this);

			  if (sym.symbol)
			    {
			      if (symbol_read_needs_frame (sym.symbol))
				innermost_block.update (sym);

			      write_exp_elt_opcode (pstate, OP_VAR_VALUE);
			      write_exp_elt_block (pstate, sym.block);
			      write_exp_elt_sym (pstate, sym.symbol);
			      write_exp_elt_opcode (pstate, OP_VAR_VALUE);
			    }
			  else
			    {
			      struct bound_minimal_symbol msymbol;
			      char *arg = copy_name ($1);

			      msymbol =
				lookup_bound_minimal_symbol (arg);
			      if (msymbol.minsym != NULL)
				write_exp_msymbol (pstate, msymbol);
			      else if (!have_full_symbols () && !have_partial_symbols ())
				error (_("No symbol table is loaded.  Use the \"symbol-file\" command."));
			      else
				error (_("No symbol \"%s\" in current context."),
				       copy_name ($1));
			    }
			}
	;

type
	:	TYPENAME
			{ $$
			    = lookup_typename (pstate->language (),
					       pstate->gdbarch (),
					       copy_name ($1),
					       pstate->expression_context_block,
					       0);
			}

	;

%%

/* Take care of parsing a number (anything that starts with a digit).
   Set yylval and return the token type; update lexptr.
   LEN is the number of characters in it.  */

/*** Needs some error checking for the float case ***/

static int
parse_number (int olen)
{
  const char *p = pstate->lexptr;
  LONGEST n = 0;
  LONGEST prevn = 0;
  int c,i,ischar=0;
  int base = input_radix;
  int len = olen;
  int unsigned_p = number_sign == 1 ? 1 : 0;

  if(p[len-1] == 'H')
  {
     base = 16;
     len--;
  }
  else if(p[len-1] == 'C' || p[len-1] == 'B')
  {
     base = 8;
     ischar = p[len-1] == 'C';
     len--;
  }

  /* Scan the number */
  for (c = 0; c < len; c++)
  {
    if (p[c] == '.' && base == 10)
      {
	/* It's a float since it contains a point.  */
	if (!parse_float (p, len,
			  parse_m2_type (pstate)->builtin_real,
			  yylval.val))
	  return ERROR;

	pstate->lexptr += len;
	return FLOAT;
      }
    if (p[c] == '.' && base != 10)
       error (_("Floating point numbers must be base 10."));
    if (base == 10 && (p[c] < '0' || p[c] > '9'))
       error (_("Invalid digit \'%c\' in number."),p[c]);
 }

  while (len-- > 0)
    {
      c = *p++;
      n *= base;
      if( base == 8 && (c == '8' || c == '9'))
	 error (_("Invalid digit \'%c\' in octal number."),c);
      if (c >= '0' && c <= '9')
	i = c - '0';
      else
	{
	  if (base == 16 && c >= 'A' && c <= 'F')
	    i = c - 'A' + 10;
	  else
	     return ERROR;
	}
      n+=i;
      if(i >= base)
	 return ERROR;
      if(!unsigned_p && number_sign == 1 && (prevn >= n))
	 unsigned_p=1;		/* Try something unsigned */
      /* Don't do the range check if n==i and i==0, since that special
	 case will give an overflow error.  */
      if(RANGE_CHECK && n!=i && i)
      {
	 if((unsigned_p && (unsigned)prevn >= (unsigned)n) ||
	    ((!unsigned_p && number_sign==-1) && -prevn <= -n))
	    range_error (_("Overflow on numeric constant."));
      }
	 prevn=n;
    }

  pstate->lexptr = p;
  if(*p == 'B' || *p == 'C' || *p == 'H')
     pstate->lexptr++;			/* Advance past B,C or H */

  if (ischar)
  {
     yylval.ulval = n;
     return CHAR;
  }
  else if ( unsigned_p && number_sign == 1)
  {
     yylval.ulval = n;
     return UINT;
  }
  else if((unsigned_p && (n<0))) {
     range_error (_("Overflow on numeric constant -- number too large."));
     /* But, this can return if range_check == range_warn.  */
  }
  yylval.lval = n;
  return INT;
}


/* Some tokens */

static struct
{
   char name[2];
   int token;
} tokentab2[] =
{
    { {'<', '>'},    NOTEQUAL 	},
    { {':', '='},    ASSIGN	},
    { {'<', '='},    LEQ	},
    { {'>', '='},    GEQ	},
    { {':', ':'},    COLONCOLON },

};

/* Some specific keywords */

struct keyword {
   char keyw[10];
   int token;
};

static struct keyword keytab[] =
{
    {"OR" ,   OROR	 },
    {"IN",    IN         },/* Note space after IN */
    {"AND",   LOGICAL_AND},
    {"ABS",   ABS	 },
    {"CHR",   CHR	 },
    {"DEC",   DEC	 },
    {"NOT",   NOT	 },
    {"DIV",   DIV    	 },
    {"INC",   INC	 },
    {"MAX",   MAX_FUNC	 },
    {"MIN",   MIN_FUNC	 },
    {"MOD",   MOD	 },
    {"ODD",   ODD	 },
    {"CAP",   CAP	 },
    {"ORD",   ORD	 },
    {"VAL",   VAL	 },
    {"EXCL",  EXCL	 },
    {"HIGH",  HIGH       },
    {"INCL",  INCL	 },
    {"SIZE",  SIZE       },
    {"FLOAT", FLOAT_FUNC },
    {"TRUNC", TRUNC	 },
    {"TSIZE", SIZE       },
};


/* Depth of parentheses.  */
static int paren_depth;

/* Read one token, getting characters through lexptr.  */

/* This is where we will check to make sure that the language and the
   operators used are compatible  */

static int
yylex (void)
{
  int c;
  int namelen;
  int i;
  const char *tokstart;
  char quote;

 retry:

  pstate->prev_lexptr = pstate->lexptr;

  tokstart = pstate->lexptr;


  /* See if it is a special token of length 2 */
  for( i = 0 ; i < (int) (sizeof tokentab2 / sizeof tokentab2[0]) ; i++)
     if (strncmp (tokentab2[i].name, tokstart, 2) == 0)
     {
	pstate->lexptr += 2;
	return tokentab2[i].token;
     }

  switch (c = *tokstart)
    {
    case 0:
      return 0;

    case ' ':
    case '\t':
    case '\n':
      pstate->lexptr++;
      goto retry;

    case '(':
      paren_depth++;
      pstate->lexptr++;
      return c;

    case ')':
      if (paren_depth == 0)
	return 0;
      paren_depth--;
      pstate->lexptr++;
      return c;

    case ',':
      if (pstate->comma_terminates && paren_depth == 0)
	return 0;
      pstate->lexptr++;
      return c;

    case '.':
      /* Might be a floating point number.  */
      if (pstate->lexptr[1] >= '0' && pstate->lexptr[1] <= '9')
	break;			/* Falls into number code.  */
      else
      {
	 pstate->lexptr++;
	 return DOT;
      }

/* These are character tokens that appear as-is in the YACC grammar */
    case '+':
    case '-':
    case '*':
    case '/':
    case '^':
    case '<':
    case '>':
    case '[':
    case ']':
    case '=':
    case '{':
    case '}':
    case '#':
    case '@':
    case '~':
    case '&':
      pstate->lexptr++;
      return c;

    case '\'' :
    case '"':
      quote = c;
      for (namelen = 1; (c = tokstart[namelen]) != quote && c != '\0'; namelen++)
	if (c == '\\')
	  {
	    c = tokstart[++namelen];
	    if (c >= '0' && c <= '9')
	      {
		c = tokstart[++namelen];
		if (c >= '0' && c <= '9')
		  c = tokstart[++namelen];
	      }
	  }
      if(c != quote)
	 error (_("Unterminated string or character constant."));
      yylval.sval.ptr = tokstart + 1;
      yylval.sval.length = namelen - 1;
      pstate->lexptr += namelen + 1;

      if(namelen == 2)  	/* Single character */
      {
	   yylval.ulval = tokstart[1];
	   return CHAR;
      }
      else
	 return STRING;
    }

  /* Is it a number?  */
  /* Note:  We have already dealt with the case of the token '.'.
     See case '.' above.  */
  if ((c >= '0' && c <= '9'))
    {
      /* It's a number.  */
      int got_dot = 0, got_e = 0;
      const char *p = tokstart;
      int toktype;

      for (++p ;; ++p)
	{
	  if (!got_e && (*p == 'e' || *p == 'E'))
	    got_dot = got_e = 1;
	  else if (!got_dot && *p == '.')
	    got_dot = 1;
	  else if (got_e && (p[-1] == 'e' || p[-1] == 'E')
		   && (*p == '-' || *p == '+'))
	    /* This is the sign of the exponent, not the end of the
	       number.  */
	    continue;
	  else if ((*p < '0' || *p > '9') &&
		   (*p < 'A' || *p > 'F') &&
		   (*p != 'H'))  /* Modula-2 hexadecimal number */
	    break;
	}
	toktype = parse_number (p - tokstart);
        if (toktype == ERROR)
	  {
	    char *err_copy = (char *) alloca (p - tokstart + 1);

	    memcpy (err_copy, tokstart, p - tokstart);
	    err_copy[p - tokstart] = 0;
	    error (_("Invalid number \"%s\"."), err_copy);
	  }
	pstate->lexptr = p;
	return toktype;
    }

  if (!(c == '_' || c == '$'
	|| (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')))
    /* We must have come across a bad character (e.g. ';').  */
    error (_("Invalid character '%c' in expression."), c);

  /* It's a name.  See how long it is.  */
  namelen = 0;
  for (c = tokstart[namelen];
       (c == '_' || c == '$' || (c >= '0' && c <= '9')
	|| (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'));
       c = tokstart[++namelen])
    ;

  /* The token "if" terminates the expression and is NOT
     removed from the input stream.  */
  if (namelen == 2 && tokstart[0] == 'i' && tokstart[1] == 'f')
    {
      return 0;
    }

  pstate->lexptr += namelen;

  /*  Lookup special keywords */
  for(i = 0 ; i < (int) (sizeof(keytab) / sizeof(keytab[0])) ; i++)
     if (namelen == strlen (keytab[i].keyw)
	 && strncmp (tokstart, keytab[i].keyw, namelen) == 0)
	   return keytab[i].token;

  yylval.sval.ptr = tokstart;
  yylval.sval.length = namelen;

  if (*tokstart == '$')
    {
      write_dollar_variable (pstate, yylval.sval);
      return DOLLAR_VARIABLE;
    }

  /* Use token-type BLOCKNAME for symbols that happen to be defined as
     functions.  If this is not so, then ...
     Use token-type TYPENAME for symbols that happen to be defined
     currently as names of types; NAME for other symbols.
     The caller is not constrained to care about the distinction.  */
 {


    char *tmp = copy_name (yylval.sval);
    struct symbol *sym;

    if (lookup_symtab (tmp))
      return BLOCKNAME;
    sym = lookup_symbol (tmp, pstate->expression_context_block,
			 VAR_DOMAIN, 0).symbol;
    if (sym && SYMBOL_CLASS (sym) == LOC_BLOCK)
      return BLOCKNAME;
    if (lookup_typename (pstate->language (), pstate->gdbarch (),
			 copy_name (yylval.sval),
			 pstate->expression_context_block, 1))
      return TYPENAME;

    if(sym)
    {
      switch(SYMBOL_CLASS (sym))
       {
       case LOC_STATIC:
       case LOC_REGISTER:
       case LOC_ARG:
       case LOC_REF_ARG:
       case LOC_REGPARM_ADDR:
       case LOC_LOCAL:
       case LOC_CONST:
       case LOC_CONST_BYTES:
       case LOC_OPTIMIZED_OUT:
       case LOC_COMPUTED:
	  return NAME;

       case LOC_TYPEDEF:
	  return TYPENAME;

       case LOC_BLOCK:
	  return BLOCKNAME;

       case LOC_UNDEF:
	  error (_("internal:  Undefined class in m2lex()"));

       case LOC_LABEL:
       case LOC_UNRESOLVED:
	  error (_("internal:  Unforseen case in m2lex()"));

       default:
	  error (_("unhandled token in m2lex()"));
	  break;
       }
    }
    else
    {
       /* Built-in BOOLEAN type.  This is sort of a hack.  */
       if (strncmp (tokstart, "TRUE", 4) == 0)
       {
	  yylval.ulval = 1;
	  return M2_TRUE;
       }
       else if (strncmp (tokstart, "FALSE", 5) == 0)
       {
	  yylval.ulval = 0;
	  return M2_FALSE;
       }
    }

    /* Must be another type of name...  */
    return NAME;
 }
}

int
m2_parse (struct parser_state *par_state)
{
  /* Setting up the parser state.  */
  scoped_restore pstate_restore = make_scoped_restore (&pstate);
  gdb_assert (par_state != NULL);
  pstate = par_state;
  paren_depth = 0;

  return yyparse ();
}

static void
yyerror (const char *msg)
{
  if (pstate->prev_lexptr)
    pstate->lexptr = pstate->prev_lexptr;

  error (_("A %s in expression, near `%s'."), msg, pstate->lexptr);
}
