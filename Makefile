DMD?=ldmd2
OPTS?=-release -O
IOPTS=$(OPTS) -IDRSS/ -IDRSS/kxml/source/

Fb2RSS: fbstream.o Fb2RSS.o DRSS/drss.a
	$(DMD) $(IOPTS) $? -of$@
%.o: %.d
	$(DMD) $(IOPTS) -c $< -of$@
.PHONY:
DRSS/drss.a: 
	cd DRSS/; make drss.a
clean:
	rm -f Fb2RSS *.o 
	cd DRSS/; make clean
