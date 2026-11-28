all:
	bison -d ruva.y
	flex ruva.l
	gcc lex.yy.c ruva.tab.c -o ruva

clean:
	rm -f lex.yy.c ruva.tab.c ruva.tab.h ruva
	rm -f output.txt examples/*/output.txt

.PHONY: all clean
