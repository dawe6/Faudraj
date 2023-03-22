--====================================================================================================================
--== PMD85 Vga konvertor pro hardware Faudraj 3.1							  © DL 2013 ==
--====================================================================================================================
--== verze h31.f1.27											 	    ==
--====================================================================================================================
--== Zdrojovy kod je mi uplne volny :-))									    ==
--== Veskere sireni a pozmenovani je povoleno									    ==
--====================================================================================================================

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.std_logic_unsigned.ALL;
entity VgaConv is port (
----------------------------------------------------------------
-- vnejsi piny pro pripojeni k PMD85
----------------------------------------------------------------
CLK18		: in std_logic;					--hodiny 18,432MHz
DATABUS		: in std_logic_vector(7 downto 0);		--datova sbernice PMD85
STB		: in std_logic;					--strobe zapisu do registru MH7496
R14ADR		: in std_logic;					--nejvyssi bit citace videoprocesoru
CSWR1		: in std_logic;					--povoleni zapisu do registru modu barev
CSWR2		: in std_logic;					--povoleni zapisu do registru modu barev
----------------------------------------------------------------
-- vnejsi piny pro pripojeni konfiguracnich prepinacu
----------------------------------------------------------------
SWITCH		: in std_logic_vector(2 downto 0);		--tri prepinace nastaveni modu
----------------------------------------------------------------
-- vnejsi piny pro pripojeni RAM
----------------------------------------------------------------
RAMADR		: out std_logic_vector(14 downto 0);		--adresni sbernice
RAMDAT		: inout std_logic_vector(7 downto 0);		--datova sbernice
RAMWRT		: out std_logic;				--povoleni zapisu
TOGND15		: out std_logic;				--nepouzity adresni vodic
TOGND16		: out std_logic;				--nepouzity adresni vodic
TOGND17		: out std_logic;				--nepouzity adresni vodic
HIDAT		: inout std_logic_vector(7 downto 0);		--nepouzita cast datove sbernice
----------------------------------------------------------------
-- vnejsi piny pro pripojeni k VGA
----------------------------------------------------------------
VGARED1		: out std_logic;				--cervena slozka vysoka intenzita
VGARED2		: out std_logic;				--cervena slozka stredni intenzita
VGARED3		: out std_logic;				--cervena slozka nizka intenzita
VGAGRN1		: out std_logic;				--zelena slozka vysoka intenzita
VGAGRN2		: out std_logic;				--zelena slozka stredni intenzita
VGAGRN3		: out std_logic;				--zelena slozka nizka intenzita
VGABLU1		: out std_logic;				--modra slozka vysoka intenzita
VGABLU2		: out std_logic;				--modra slozka stredni intenzita
VGABLU3		: out std_logic;				--modra slozka nizka intenzita
VGAHSYNC	: out std_logic;				--horizontalni synchronizace
VGAVSYNC	: out std_logic);				--vertikalni synchronizace
----------------------------------------------------------------

end VgaConv;
architecture rtl of VgaConv is

----------------------------------------------------------------
-- vnitrni signaly pro vstupni cast
----------------------------------------------------------------
signal inCTC	: std_logic_vector(13 downto 0);		--citac vstupniho obrazu
signal dataBUSr	: std_logic_vector(7 downto 0);			--register vstupnich dat
signal inPAGE	: std_logic;					--vyber stranky do ktere se zapisuje
----------------------------------------------------------------
-- vnitrni signaly pro VGA cast
----------------------------------------------------------------
signal vgaCTCH	: std_logic_vector(5 downto 0);			--VGA horizontalni citac
signal vgaCTCI	: std_logic_vector(3 downto 0);			--VGA citac pixelu
signal vgaCTCV	: std_logic_vector(8 downto 0);			--VGA vertikalni citac
signal vgaCTCW	: std_logic_vector(1 downto 0);			--VGA citac mikroradku
signal vgaENAB	: std_logic;					--povoleni zobrazeni
signal vgaENAv	: std_logic;					--povoleni zobrazeni od vertikalniho citace
signal vgaPAGE	: std_logic;					--vyber stranky ze ktere se zobrazuje
signal dataRAM	: std_logic_vector(7 downto 0);			--register pro data z RAM
signal coloramR	: std_logic_vector(7 downto 0);			--pred register pro barvy z RAM
signal coloRAM	: std_logic_vector(7 downto 0);			--register pro barvy z RAM
signal blikCTC	: std_logic_vector(6 downto 0);			--citac delicky pro blikani
signal clrace	: std_logic_vector(3 downto 0);			--pomocny register pro ColorAce
signal vgired	: std_logic;					--interni cervena slozka vysoky jas
signal vgigrn1	: std_logic;					--interni zelena slozka vysoky jas
signal vgigrn2	: std_logic;					--interni zelena slozka stredni jas
signal vgigrn3	: std_logic;					--interni zelena slozka nizky jas
signal vgiblue	: std_logic;					--interni modra slozka vysoky jas
----------------------------------------------------------------
-- vnitrni signaly pro zapis do pameti RAM
----------------------------------------------------------------
signal wrREQ1	: std_logic_vector(1 downto 0);			--register pozadavku zapisu ze vstupni casti
signal wrREQ2	: std_logic;					--pamet pozadavku zapisu pro VGA cast
signal wrREQ3	: std_logic;					--interni signal WR pro pamet RAM
----------------------------------------------------------------
-- vnitrni signaly pro mod zobrazeni
----------------------------------------------------------------
signal iCSWR	: std_logic;					--interni signal CSWR
signal cswrR	: std_logic;					--register signalu CSWR
signal switchRG	: std_logic_vector(2 downto 0);			--register signalu SWITCH
signal vMODE	: std_logic_vector(2 downto 0);			--typ nastaveneho modu
----------------------------------------------------------------

begin

iCSWR <= CSWR1 or CSWR2;					--ze dvou CSWR jeden
--====================================================================================================================
--Vstupni cast od PMD85
--====================================================================================================================
process (STB) begin
    if STB'event and STB='1' then
	dataBUSr <= DATABUS;					--registruj vstupni data
	inCTC <= inCTC +'1';					--citac vstupniho obrazu +1
	if R14ADR = '1' then
	   inCTC <= (others=>'1');				--nulovani citace vstupniho obrazu (na hodnotu -1)
	elsif inCTC=16383 then
	   inPAGE <= not inPAGE;				--zmena zapisove stranky
	end if;
    end if;
end process;
----------------------------------------------------------------

process (CLK18) begin
    if CLK18'event and CLK18='1' then

----------------------------------------------------------------
-- zapis modu zobrazeni
----------------------------------------------------------------
	cswrR <= iCSWR;						--registruj signal CSWR
	switchRG <= SWITCH;					--registruj signaly SWITCH
	if switchRG /= SWITCH then				--pokud se nastaveni SWITCH zmenilo
	    vMODE <= SWITCH;					--nastav mod zobrazeni podle SWITCH
	elsif iCSWR='0' and cswrR='1' then			--pokud je detekovana sestupna hrana na wrMODbus
	    vMODE <= DATABUS(2 downto 0);			--nastav mod zobrazeni podle DATABUS
	end if;

----------------------------------------------------------------
-- detekce zapisu do pameti RAM od vstupni casti a generovani zapisu do pameti RAM
----------------------------------------------------------------
	wrREQ1 <= STB & wrREQ1(1);				--registruj pozadavek o zapis ze vstupni casti
	wrREQ2 <= '0';						--interni pozadavek zapisu je defaultne neaktivni
	wrREQ3 <= '1';						--zapis je defaultne neaktivni
	if wrREQ1="10" or wrREQ2='1' then			--je detekovan pozadavek o zapis?
	    if vgaCTCI=5 then					--je mozne zapis provest?
		wrREQ3 <= '0';					--nastav vnitrni signal /WR
	    else						--pokud ho nelze vykonat
		wrREQ2 <= '1';					--nastav interni pozadavek o zapis
	    end if;
	end if;

--====================================================================================================================
--Vystupni VGA cast
--====================================================================================================================
-- VGA - citani, nulovani horizontalniho a vertikalniho citace
----------------------------------------------------------------
	if vgaCTCH=63 and vgaCTCI=2 then			--pokud jsme docitali sloupce na radku
	    vgaCTCH <= (others=>'0');				--nulovani horizontalniho citace
	    vgaCTCI <= (others=>'0');				--nulovani citace pixelu
	    if vgaCTCV=268 then					--pokud jsme docitali radky na strance
		vgaCTCV <= (others=>'0');			--nulovani vertikalniho citace
		vgaCTCW <= (others=>'0');			--nulovani citace mikroradku
		blikCTC <= blikCTC +1;				--citac blikani +1
		vgaPAGE <= not inPAGE;				--preklopeni do pameti do ktere se nezapisuje
	    elsif vgaCTCW=2 then				--jsme na tretim mikroradku?
		vgaCTCW <= (others=>'0');			--nulovani citace mikroradku
		vgaCTCV <= vgaCTCV +'1';			--vertikalni citac +1
	    else
		vgaCTCW <= vgaCTCW +'1';			--na dalsi mikroradek
	    end if;
	elsif vgaCTCI=5 then					--je to posledni pixel?
	    vgaCTCI <= (others=>'0');				--nulovani citace pixelu
	    vgaCTCH <= vgaCTCH +'1';				--horizontalni citac +1
	else
	    vgaCTCI <= vgaCTCI +'1';				--citac pixelu +1
	end if;
----------------------------------------------------------------
-- VGA - generovani vertikalni synchronizace
----------------------------------------------------------------
	if vgaCTCV=0 then
	    vgaENAv <= '1';					--povoleni zobrazeni
	elsif vgaCTCV=256 then
	    vgaENAv <= '0';					--zakazani zobrazeni
	elsif vgaCTCV=257 then
	    VGAVSYNC <= '0';					--zacatek vertikalni synchronizace
	elsif vgaCTCV=259 then
	    VGAVSYNC <= '1';					--konec vertikalni synchronizace
	end if;
----------------------------------------------------------------
-- VGA - generovani horizontalni synchronizace
----------------------------------------------------------------
	if vgaCTCH=0 and vgaCTCI=5 and vgaENAv='1' then
	    vgaENAB <= '1';					--povoleni zobrazovani
	elsif vgaCTCH=48 and vgaCTCI=5 then
	    vgaENAB <= '0';					--zakazani zobrazovani
	elsif vgaCTCH=50 and vgaCTCI=3 then
	    VGAHSYNC <= '0';					--zacatek horizontalni synchronizace
	elsif vgaCTCH=57 then
	    VGAHSYNC <= '1';					--konec horizontalni synchronizace
	end if;
----------------------------------------------------------------
-- VGA - cteni dat z pameti a jejich zapis do registru, rotace registru
----------------------------------------------------------------
	if vgaCTCI=5 then
	    dataRAM <= RAMDAT(7 downto 0);			--nacteni bajtu z RAM
	    coloRAM <= coloramR;				--nacteni barevnych atributu
	else
	    dataRAM(4 downto 0) <= dataRAM(5 downto 1);		--posunuti na dalsi pixel
	    if vgaCTCI=1 then
		coloramR(7 downto 6) <= RAMDAT(7 downto 6);	--nacteni 0-radku barvy z RAM
	    elsif vgaCTCI=2 then
		coloramR(5 downto 4) <= RAMDAT(7 downto 6);	--nacteni 1-radku barvy z RAM
	    elsif vgaCTCI=4 then
		coloramR(3 downto 2) <= RAMDAT(7 downto 6);	--nacteni 2-radku barvy z RAM
	    elsif vgaCTCI=3 then
		coloramR(1 downto 0) <= RAMDAT(7 downto 6);	--nacteni 3-radku barvy z RAM
	    end if;
	end if;
----------------------------------------------------------------
    end if;
end process;
----------------------------------------------------------------
-- VGA - generovani signalu pro barvy
----------------------------------------------------------------
clrace	<= "0000" when dataRAM(0)='0' else			--mux pro ColorAce
	   coloRAM(7 downto 4) when vgaCTCV(1)='0' else
	   coloRAM(3 downto 0);
vgigrn1	<= '0' when vgaENAB='0' else				--zobrazovani zakazano
	   coloRAM(6) when dataRAM(0)='1' and vMODE=0 else	--mod pixel HexaC
	   coloRAM(2) when dataRAM(0)='0' and vMODE=0 else	--mod paper HexaC
	   '0' when dataRAM(0)='0' else				--neni pixel
	   not((clrace(3) or clrace(2)) and (clrace(1)		--mod ColorAce
		or clrace(0))) when vMODE=1 else
	   '0' when dataRAM(7 downto 6)/=0 and vMODE=2 else	--mod color PMD85.3 - jina nez zelena barva
	   '0' when blikCTC(6)='0' and dataRAM(7)='1'		--mod mono PMD85.1 - aktivni blikani
		and vMODE(2 downto 1)=3 else
	   '0' when dataRAM(7)='1' and vMODE(2 downto 1)=2 else	--mod mono PMD85.3 - vysoke potlaceni jasu
	   '0' when dataRAM(6)='1' and vMODE(2 downto 1)=3 else	--mod mono PMD85.1 - potlaceni jasu
	   '0' when dataRAM(6)='1' and vMODE=3 else		--mod color PMD85.1 - potlaceni jasu zelene slozky
	   '1';							--jinak aktivni pixel
vgigrn2	<= '0' when vgaENAB='0' else				--zobrazovani zakazano
	   coloRAM(4) when dataRAM(0)='1' and vMODE=0 else	--mod HexaC pixel
	   coloRAM(0) when dataRAM(0)='0' and vMODE=0 else	--mod HexaC paper
	   '0' when dataRAM(0)='0' else				--neni pixel
	   '0' when dataRAM(7 downto 6)=1			--vyjimka v modu mono PMD85.3
		and vMODE(2 downto 1)=2 else
	   '0' when blikCTC(6)='0' and dataRAM(7)='1'		--mod mono PMD85.1 - aktivni blikani
		and vMODE(2 downto 1)=3 else
	   '1' when vMODE(2)='1' else				--aktivni ve vsech mono modech
	   '1' when vMODE=3 else				--aktivni v modu color PMD85.1
	   vgigrn1;						--jinak jako hlavni zelena barva
vgigrn3	<= '0' when vgaENAB='0' else				--zobrazovani zakazano
	   not dataRAM(6) when vMODE(2 downto 1)=2		--aktivni muze byt jen v modu mono PMD85.3
		and dataRAM(0)='1' else '0';
vgired	<= '0' when vgaENAB='0' else				--zobrazovani zakazano
	   coloRAM(7) when dataRAM(0)='1' and vMODE=0 else	--mod pixel HexaC
	   coloRAM(3) when dataRAM(0)='0' and vMODE=0 else	--mod paper HexaC
	   '0' when dataRAM(0)='0' else				--neni pixel
	   (clrace(2) or clrace(0)) when vMODE=1 else		--mod ColorAce
	   '0' when vMODE(2)='1' and vMODE(0)='0' else		--mody mono cerno-zelene
	   vgigrn1 when vMODE(2)='1' and vMODE(0)='1' else	--mody mono cerno-bile
	   dataRAM(6);						--jinak barva
vgiblue	<= '0' when vgaENAB='0' else				--zobrazovani zakazano
	   coloRAM(5) when dataRAM(0)='1' and vMODE=0 else	--mod pixel HexaC
	   coloRAM(1) when dataRAM(0)='0' and vMODE=0 else	--mod paper HexaC
	   '0' when dataRAM(0)='0' else				--neni pixel
	   (clrace(3) or clrace(1)) when vMODE=1 else		--mod ColorAce
	   '0' when vMODE(2)='1' and vMODE(0)='0' else		--mody mono cerno-zelene
	   vgigrn1 when vMODE(2)='1' and vMODE(0)='1' else	--mody mono cerno-bile
	   dataRAM(7);						--jinak barva
VGARED1	<= vgired;
VGARED2	<= '0' when vMODE(2)='1' and vMODE(0)='0' else		--mody mono cerno-zelene
	   vgigrn2 when (vMODE(2)='1' and vMODE(0)='1')		--mody mono cerno-bile nebo mod HexaC
		or vMODE=0 else
	   vgired;						--jinak jako cervena slozka vysoky jas
VGARED3	<= vgigrn3 when vMODE=5 else '0';			--aktivni jen pro cerno-bily mod mono PMD85.3
VGAGRN1	<= vgigrn1;
VGAGRN2	<= vgigrn2;
VGAGRN3	<= vgigrn3;
VGABLU1	<= vgiblue;
VGABLU2	<= '0' when vMODE(2)='1' and vMODE(0)='0' else		--mody mono cerno-zelene
	   vgigrn2 when (vMODE(2)='1' and vMODE(0)='1')		--mody mono cerno-bile nebo mod HexaC
		or vMODE=0 else
	   vgiblue;						--jinak jako modra slozka vysoky jas
VGABLU3	<= vgigrn3 when vMODE=5 else '0';			--aktivni jen pro cerno-bily mod mono PMD85.3
--====================================================================================================================
-- napojeni pameti RAM
--====================================================================================================================
RAMADR <= inPAGE & inCTC when wrREQ3='0' else			--1.takt zapis
	  vgaPAGE & vgaCTCV(7 downto 2) & '0' & '0' & vgaCTCH	--2.takt cteni 0 radku
		when vgaCTCI=1 else
	  vgaPAGE & vgaCTCV(7 downto 2) & '0' & '1' & vgaCTCH	--3.takt cteni 1 radku
		when vgaCTCI=2 else
	  vgaPAGE & vgaCTCV(7 downto 2) & '1' & '1' & vgaCTCH	--4.takt cteni 3 radku
		when vgaCTCI=3 else
	  vgaPAGE & vgaCTCV(7 downto 2) & '1' & '0' & vgaCTCH	--5.takt cteni 2 radku
		when vgaCTCI=4 else
	  vgaPAGE & vgaCTCV(7 downto 0) & vgaCTCH;		--6.takt cteni pixelu + atributorove bity
RAMDAT <= dataBUSr when wrREQ3='0' else "ZZZZZZZZ";		--datova sbernice
RAMWRT <= wrREQ3;						--signal WR
TOGND15 <= '0';							--nepouzity adresni vodic
TOGND16 <= '0';							--nepouzity adresni vodic
TOGND17 <= '0';							--nepouzity adresni vodic
HIDAT <= "00000000" when wrREQ3='0' else "ZZZZZZZZ";		--nepouzita cast datove sbernice
----------------------------------------------------------------
end rtl;
