--============================================================================
--== Sharp MZ-800 Vga konvertor pro hardware Faudraj 3.1		    ==
--============================================================================
--== verze h31.f3.34						  © DL 2013 ==
--============================================================================
--== Zdrojovy kod je mi uplne volny :-))				    ==
--==				   Veskere sireni a pozmenovani je povoleno ==
--============================================================================
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.std_logic_unsigned.ALL;
entity VgaConv is port (
------------------------------------------------------------------------------
-- vnejsi piny pro pripojeni k Sharp MZ-800
------------------------------------------------------------------------------
RGBI		: in std_logic_vector(3 downto 0);			--barevne slozky
VSYNC		: in std_logic;						--vertikalni synchronizace
CLK17		: in std_logic;						--hodiny 17.734475MHz
------------------------------------------------------------------------------
-- vnejsi piny pro pripojeni konfiguracnich prepinacu
------------------------------------------------------------------------------
SWITCH		: in std_logic_vector(3 downto 0);			--ctyri konfiguracni prepinace
------------------------------------------------------------------------------
-- vnejsi pin hodin
------------------------------------------------------------------------------
CLK25		: in std_logic;						--hodiny 25MHz
------------------------------------------------------------------------------
-- vnejsi piny pro pripojeni RAM
------------------------------------------------------------------------------
RAMADR		: out std_logic_vector(17 downto 0);			--adresni sbernice
RAMDAT		: inout std_logic_vector(15 downto 0);			--datova sbernice
RAMWRT		: out std_logic;					--povoleni zapisu
------------------------------------------------------------------------------
-- vnejsi piny pro pripojeni k VGA
------------------------------------------------------------------------------
VGARED1		: out std_logic;					--cervena barva vysoka intenzita
VGARED2		: out std_logic;					--cervena barva stredni intenzita
VGARED3		: out std_logic;					--cervena barva nizka intenzita
VGAGRN1		: out std_logic;					--zelena barva vysoka intenzita
VGAGRN2		: out std_logic;					--zelena barva stredni intenzita
VGAGRN3		: out std_logic;					--zelena barva nizka intenzita
VGABLU1		: out std_logic;					--modra barva vysoka intenzita
VGABLU2		: out std_logic;					--modra barva stredni intenzita
VGABLU3		: out std_logic;					--modra barva nizka intenzita
VGAHSYNC	: out std_logic;					--horizontalni synchronizace
VGAVSYNC	: out std_logic);					--vertikalni synchronizace
------------------------------------------------------------------------------
end VgaConv;
architecture rtl of VgaConv is
----------------------------------------------------------------
-- vnitrni signaly pro vstupni cast
----------------------------------------------------------------
signal rVSYNC	: std_logic;						--pamet stavu signalu VSYNC
signal inCTCH	: std_logic_vector(10 downto 0);			--horizontalni citac vstupniho obrazu
signal inCTCV	: std_logic_vector(8 downto 0);				--vertikalni citac vstupniho obrazu
signal in3PIX	: std_logic_vector(11 downto 0);				--pomocna pamet pro 3 pixely na vstupu
signal in4PIX	: std_logic_vector(15 downto 0);			--pamet pro 4 pixely na vstupu (slovo pro zapis do RAM)
signal inNTSC	: std_logic;						--jedna se o PAL nebo NTSC
signal inPAGE	: std_logic;						--vyber stranky do ktere se zapisuje
------------------------------------------------------------------------------
-- vnitrni signaly pro VGA cast
------------------------------------------------------------------------------
signal CLK50	: std_logic;						--frekvence 50MHz
signal retCLK	: std_logic;						--zpetna vazba nasobicky frekvence
signal vgaCTCH	: std_logic_vector(10 downto 0);			--VGA horizontalni citac
signal vgaCTCV	: std_logic_vector(9 downto 0);				--VGA vertikalni citac
signal vgaENAB	: std_logic;						--povoleni zobrazeni
signal vgaENAv	: std_logic;						--povoleni zobrazeni od vertikalniho citace
signal vgaPAGE	: std_logic;						--vyber stranky ze ktere se zobrazuje
signal vga4PIX	: std_logic_vector(15 downto 0);			--pamet pro 4 pixely na vystupu (slovo prectene z RAM)
signal vgaREGH	: std_logic_vector(3 downto 0);				--pomocny horizontalni register
signal vgaREGV	: std_logic_vector(5 downto 0);				--pomocny vertikalni register
signal vgaINT1	: std_logic;						--barevna intenzita
signal vgaINT2	: std_logic;						--pomocna barevna intenzita
--############################################################################
--## Funkce pro nastaveni obrazu na stred				    ##
--signal vgaBENA : std_logic;	--povoleni zobrazeni borderu
--signal vgaBENv : std_logic;	--povoleni zobrazeni borderu od vertikalniho citace
--############################################################################
------------------------------------------------------------------------------
-- vnitrni signaly pro zapis do pameti RAM
------------------------------------------------------------------------------
signal wrREQ1	: std_logic;						--pozadavek zapisu ze vstupni casti
signal wrREQ2	: std_logic_vector(1 downto 0);				--register pozadavku zapisu ze vstupni casti
signal wrREQ3	: std_logic;						--pamet pozadavku zapisu pro VGA cast
signal wrREQ4	: std_logic;						--interni signal WR pro pamet RAM
------------------------------------------------------------------------------
begin
--============================================================================
--Vstupni cast od MZ-800
--============================================================================
process (CLK17) begin
    if CLK17'event and CLK17='1' then
	rVSYNC <= VSYNC;						--pamet stavu VSYNC
	wrREQ1 <= '0';							--pozadavek o zapis je defaultne neaktivni
	inCTCH(1 downto 0) <= inCTCH(1 downto 0) +'1';			--citac pixelu +1
	if inCTCH(1 downto 0)=0 then
	    in3PIX(3 downto 0) <= RGBI;					--registruj prvni pixel do pomocneho registru
	elsif inCTCH(1 downto 0)=1 then
	    in3PIX(7 downto 4) <= RGBI;					--registruj druhy pixel do pomocneho registru
	elsif inCTCH(1 downto 0)=2 then
	    in3PIX(11 downto 8) <= RGBI;				--registruj treti pixel do pomocneho registru
	elsif inCTCH(1 downto 0)=3 then
	    in4PIX <= RGBI & in3PIX;					--registruj vsechny pixely do hlavniho registru
	    inCTCH(10 downto 2) <= inCTCH(10 downto 2)+'1';		--nastav citac na dalsi ctverici pixelu
	    wrREQ1 <= not inCTCH(10);					--nastav pozadavek o zapis
	end if;
	if (inCTCH=1135 and inNTSC='0')					--pokud je docitano na konec radku
				or (inCTCH=911 and inNTSC='1') then
	    inCTCH <= (others=>'0');					--nulovani horizontalniho citace
	    inCTCV <= inCTCV + 1;					--vertikalni citac +1
	end if;
	if rVSYNC='0' and VSYNC='1' then				--detekovana nabezna hrana VSYNC
	    if inCTCV < 290 then					--je to NTSC nebo PAL?
		inCTCH <= "11100111101";				--inicializace horizontalniho citace NTSC
		inCTCV <= "000001100";					--inicializace vertikalniho citace NTSC
		inNTSC <= '1';						--nastaveni registru na NTSC
	    else
		inCTCH <= "11001011101";				--inicializace horizontalniho citace PAL
		inCTCV <= "111110010";					--inicializace vertikalniho citace PAL
		inNTSC <= '0';						--nastaveni registru na PAL
	    end if;
	    if SWITCH(0)='1' then					--pouze pokud neni stop stav
		inPAGE <= not inPAGE;					--preklopeni do druhe poloviny pameti
	    end if;
	end if;
    end if;
end process;
--============================================================================
--Vystupni cast vga
--============================================================================
CLK50 <= CLK25 xor retCLK;						--funkce nasobicky frekvence
process (CLK50) begin
    if CLK50'event and CLK50='0' then
	retCLK <= not retCLK;						--generovani zpetne vazby nasobicky frekvence
----------------------------------------------------------------
-- detekce zapisu do pameti RAM od vstupni casti a generovani zapisu do pameti RAM
----------------------------------------------------------------
	wrREQ2 <= wrREQ1 & wrREQ2(1);					--registruj pozadavek o zapis ze vstupni casti
	wrREQ3 <= '0';							--interni pozadavek zapisu je defaultne neaktivni
	wrREQ4 <= '1';							--zapis je defaultne neaktivni
	if wrREQ2="10" or wrREQ3='1' then				--je detekovan pozadavek o zapis?
		if vgaCTCH(1 downto 0)/=2 then				--je mozne zapis provest?
		    wrREQ4 <= '0';					--nastav vnitrni signal /WR
		else							--pokud ho nelze vykonat
		    wrREQ3 <= '1';					--nastav interni pozadavek o zapis
		end if;
	end if;
------------------------------------------------------------------------------
-- VGA - citani, nulovani horizontalniho a vertikalniho citace
------------------------------------------------------------------------------
	if vgaCTCH=1039 then						--pokud jsme docitali sloupce na radku
	    vgaCTCH <= (others=>'0');					--nulovani horizontalniho citace
	    if vgaCTCV=665 then						--pokud jsme docitali radky na strance
		vgaCTCV <= (others=>'0');				--nulovani vertikalniho citace
		vgaPAGE <= not inPAGE;					--preklopeni do pameti do ktere se nezapisuje
	    else
		vgaCTCV <= vgaCTCV + '1';				--vertikalni citac +1
	    end if;
	else
	    vgaCTCH <= vgaCTCH + '1';					--horizontalni citac +1
	end if;
------------------------------------------------------------------------------
-- VGA - generovani vertikalni synchronizace
------------------------------------------------------------------------------
	if vgaCTCV=0 then
	    vgaENAv <= '1';						--povoleni zobrazeni
	elsif vgaCTCV=600 then
	    vgaENAv <= '0';						--zakazani zobrazeni
	elsif vgaCTCV=637 then
	    VGAVSYNC <= '1';						--zacatek vertikalni synchronizace
	elsif vgaCTCV=643 then
	    VGAVSYNC <= '0';						--konec vertikalni synchronizace
--############################################################################
--## Funkce pro nastaveni obrazu na stred				    ##
--elsif vgaCTCV=500 then
--vgaBENv <= '1';	--povoleni zobrazeni borderu od vertikalniho citace
--elsif vgaCTCV=100 then
--vgaBENv <= '0';	--zakazani zobrazeni borderu od vertikalniho citace
--############################################################################
	end if;
------------------------------------------------------------------------------
-- VGA - generovani horizontalni synchronizace
------------------------------------------------------------------------------
	if vgaCTCH=7 and vgaENAv='1' then
	    vgaENAB <= '1';						--povoleni zobrazovani
	elsif vgaCTCH=807 then
	    vgaENAB <= '0';						--zakazani zobrazovani
	elsif vgaCTCH=863 then
	    VGAHSYNC <= '1';						--zacatek horizontalni synchronizace
	elsif vgaCTCH=983 then
	    VGAHSYNC <= '0';						--konec horizontalni synchronizace
--############################################################################
--## Funkce pro nastaveni obrazu na stred				    ##
--elsif vgaCTCH=727 then
--vgaBENA <= '1';	--povoleni zobrazovani borderu
--elsif vgaCTCH=87 and vgaBENv='0' then
--vgaBENA <= '0';	--zakazani zobrazovani borderu
--############################################################################
	end if;
------------------------------------------------------------------------------
-- VGA - cteni dat z pameti a jejich zapis do registru, rotace registru, uprava adresy pro pamet
------------------------------------------------------------------------------
	if vgaCTCH(1 downto 0)=3 then
	    vga4PIX <= RAMDAT;						--zapis prectenych dat z pameti do registru
	else
	    vga4PIX(11 downto 0) <= vga4PIX(15 downto 4);		--posunuti registru o ctyri bity = dalsi pixel
	    if vgaCTCH(1 downto 0)=0 then				--uprava adresy se provadi jen v tomto cyklu
		vgaREGH	 <= vgaCTCH(5 downto 2);			--default nastaveni registru pro horizontal
		vgaREGV	 <= vgaCTCV(6 downto 1);			--default nastaveni registru pro vertikal
		if inNTSC='0' then					--UPRAVY PRO PAL
		    if vgaCTCV(9 downto 1)<5 then			--    pokud je radek mensi nez 5
			vgaREGV	 <= "000101";				--        zobrazuj radek 5
		    elsif vgaCTCV(9 downto 1)>290 then			--    pokud je radek vetsi nez 290
			vgaREGV	 <= "100010";				--        zobrazuj radek 290
		    end if;
		else							--UPRAVY PRO NTSC
		    if vgaCTCH(9 downto 2)<7 then			--    pokud je sloupec mensi nez 28
			vgaREGH	 <= "0111";				--        zobrazuj sloupec 28-32
		    elsif vgaCTCH(9 downto 2)>193 then			--    pokud je sloupec vetsi nez 772
			vgaREGH	 <= "0001";				--        zobrazuj sloupec 772-776
		    end if;
		    if vgaCTCV(9 downto 1)<26 then			--    pokud je radek mensi nez 26
			vgaREGV	 <= "011010";				--        zobrazuj radek 26
		    elsif vgaCTCV(9 downto 1)>266 then			--    pokud je radek vetsi nez 266
			vgaREGV	 <= "001010";				--        zobrazuj radek 266
		    end if;
		end if;
	    end if;
	end if;
------------------------------------------------------------------------------
    end if;
end process;
------------------------------------------------------------------------------
-- VGA - generovani signalu pro barvy
------------------------------------------------------------------------------
vgaINT1 <= '0' when vgaENAB='0' else					--zobrazovani zakazano
	   '0' when SWITCH(3 downto 2)=2 and vgaCTCV(0)='1' else	--nepouzije se u scanlines na kazdem lichem radku
	   vga4PIX(3) when SWITCH(1)='1' else				--bez inverze
	   not vga4PIX(3);						--s inverzi
--############################################################################
--## Funkce pro nastaveni obrazu na stred				    ##
--vgaINT2 <=  vgaBENA when vgaENAB='1' and SWITCH(3 downto 1)=7 else '0';
--############################################################################
vgaINT2 <= '0' when vgaENAB='0' else					--zobrazovani zakazano
	   '0' when SWITCH(3 downto 2)=3 else				--nepouzije se pokud jsou jeji funkce zakazany
	   '0' when SWITCH(3 downto 2)=2 and vgaCTCV(0)='1' else	--nepouzije se u scanlines na kazdem lichem radku
	   '0' when SWITCH(3 downto 2)=1 and (vga4PIX(3) xor SWITCH(1))='0' else	--nepouzije se u modu1 pri aktivni intensite
	   '1';
VGARED1 <= '0' when vgaENAB='0' else					--cervena barva vysoka intenzita
	   vga4PIX(0) when SWITCH(1)='1' else				--barva bez inverze
	   not vga4PIX(0);						--barva s inverzi
VGAGRN1 <= '0' when vgaENAB='0' else					--zelena barva vysoka intenzita
	   vga4PIX(1) when SWITCH(1)='1' else				--barva bez inverze
	   not vga4PIX(1);						--barva s inverzi
VGABLU1 <= '0' when vgaENAB='0' else					--modra barva vysoka intenzita
	   vga4PIX(2) when SWITCH(1)='1' else				--barva bez inverze
	   not vga4PIX(2);						--barva s inverzi
VGARED2 <= vgaINT1;							--cervena barva stredni intenzita
VGAGRN2 <= vgaINT1;							--zelena barva stredni intenzita
VGABLU2 <= vgaINT1;							--modra barva stredni intenzita
VGARED3 <= vgaINT2;							--cervena barva nizka intenzita
VGAGRN3 <= vgaINT2;							--zelena barva nizka intenzita
VGABLU3 <= vgaINT2;							--modra barva nizka intenzita
--============================================================================
-- napojeni pameti RAM
--============================================================================
RAMADR <= inPAGE & inCTCV(8 downto 0) & inCTCH(9 downto 2) when wrREQ4='0' else
	  vgaPAGE & vgaCTCV(9 downto 7) & vgaREGV & vgaCTCH(9 downto 6) & vgaREGH;
RAMDAT <= in4PIX when wrREQ4='0' else "ZZZZZZZZZZZZZZZZ";
RAMWRT <= wrREQ4;
----------------------------------------------------------------------------------------------------------------------
end rtl;
