DMD?=dmd
OPTS?=-release -O
IOPTS=$(OPTS) -IDRSS/ -IDRSS/kxml/source/ -Istandardpaths/source/

Fb2RSS: fbstream.o Fb2RSS.o DRSS/drss.a standardpaths/libstandardpaths.a
	$(DMD) $(IOPTS) $^ -of$@
captcha: captcha.o fbstream.o DRSS/drss.a standardpaths/libstandardpaths.a
	$(DMD) $(IOPTS) $^ -of$@
standardpaths/libstandardpaths.a: standardpaths/source/standardpaths.o
	$(DMD) $(IOPTS) -lib $^ -of$@
%.o: %.d
	$(DMD) $(IOPTS) -c $< -of$@
.PHONY:
DRSS/drss.a: 
	cd DRSS/; make drss.a
clean:
	rm -f Fb2RSS *.o 
	cd DRSS/; make clean
