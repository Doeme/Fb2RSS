DMD?=dmd
OPTS?=-release -O
IOPTS=$(OPTS) -IDRSS/ -IDRSS/kxml/source/ -Istandardpaths/source/

all: Fb2RSS captcha

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
	cd DRSS/; make DMD="$(DMD)" OPTS="$(OPTS) -version=FORGIVING" drss.a
clean:
	rm -f *.o standardpaths/source/standardpaths.o
	cd DRSS/; make clean
distclean: clean
	rm -f Fb2RSS captcha
