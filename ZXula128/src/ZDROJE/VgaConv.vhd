--============================================================================
--== Sinclair ZX Spectrum 128k (+2) Vga konvertor pro hardware Faudraj 3.1  ==
--============================================================================
--== verze h31.f3.06						  © DL 2013 ==
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
-- vnejsi piny pro pripojeni k Didaktiku M
------------------------------------------------------------------------------
RGBI		: in std_logic_vector(3 downto 0);			--barevne slozky
SYNC		: in std_logic;						--synchronizace
CLK17		: in std_logic;						--hodiny 17,7345MHz
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
------------------------------------------------------------------------------
-- vnitrni signaly pro vstupni cast
------------------------------------------------------------------------------
signal clk35	: std_logic;						--vynasobena frekvence CLK17 na 35,469MHz
signal retCLK	: std_logic;						--zpetna vazba nasobicky frekvence
signal inDIV5	: std_logic_vector(2 downto 0);				--citac pro deleni 5
signal rSYNC	: std_logic;						--pamet stavu signalu SYNC
signal inCTCH	: std_logic_vector(8 downto 0);				--horizontalni citac vstupniho obrazu
signal inCTCV	: std_logic_vector(8 downto 0);				--vertikalni citac vstupniho obrazu
signal in3PIX	: std_logic_vector(11 downto 0);			--pomocny register pro 3 pixely na vstupu
signal in4PIX	: std_logic_vector(15 downto 0);			--register pro 4 pixely na vstupu (slovo pro zapis do RAM)
signal inPAGE	: std_logic;						--vyber stranky do ktere se zapisuje
------------------------------------------------------------------------------
-- vnitrni signaly pro zapis do pameti RAM
------------------------------------------------------------------------------
signal wrREQ1	: std_logic;						--pozadavek zapisu ze vstupni casti
signal wrREQ2	: std_logic_vector(1 downto 0);				--register pozadavku zapisu ze vstupni casti
signal wrREQ3	: std_logic;						--pamet pozadavku zapisu pro VGA cast
signal wrREQ4	: std_logic;						--interni signal WR pro pamet RAM
------------------------------------------------------------------------------
-- vnitrni signaly pro VGA cast
------------------------------------------------------------------------------
signal vgaDIV	: std_logic;						--delicka kmitoctu
signal vgaCTCH	: std_logic_vector(8 downto 0);				--VGA horizontalni citac
signal vgaCTCV	: std_logic_vector(9 downto 0);				--VGA vertikalni citac
signal vgaENAB	: std_logic;						--povoleni zobrazeni
signal vgaENAv	: std_logic;						--povoleni zobrazeni od vertikalniho citace
signal vgaPAGE	: std_logic;						--vyber stranky ze ktere se zobrazuje
signal vga4PIX	: std_logic_vector(15 downto 0);			--pamet pro 4 pixely na vystupu (slovo prectene z RAM)
signal vgaPIX	: std_logic_vector(3 downto 0);				--barevny vystup, prvni cast upravy barev
signal vgaINT	: std_logic;						--pomocna barevna intenzita
--############################################################################
--## Funkce pro nastaveni obrazu na stred				    ##
--signal vgaBENA : std_logic;	--povoleni zobrazeni borderu
--signal vgaBENv : std_logic;	--povoleni zobrazeni borderu od vertikalniho citace
--############################################################################
------------------------------------------------------------------------------
begin
--============================================================================
--Vstupni cast od 128k
--============================================================================
clk35 <= CLK17 xor retCLK;						--nasobicka frekvence
process (clk35) begin
    if clk35'event and clk35='0' then
	retCLK <= not retCLK;						--generovani zpetne vazby nasobicky frekvence
	inDIV5 <= inDIV5 +'1';						--citac delicky kmitoctu +1
	if inDIV5=4 then
	    inDIV5 <= (others=>'0');					--inicializace delicky kmitoctu
	    rSYNC <= SYNC;						--pamet stavu SYNC
	    wrREQ1 <= '0';						--pozadavek o zapis neni aktivni
	    inCTCH(1 downto 0) <= inCTCH(1 downto 0) +'1';		--citac pixelu +1
	    if inCTCH=254 and rSYNC='0' then				--pokud nekde uprostred radku trva sync
		inCTCV <= "111011101";					--inicializace vertikalniho citace
	    end if;
	    if rSYNC='1' and SYNC='0' then				--detekovana sestupna hrana SYNC
		inCTCH <= "110011100";					--inicializace horizontalniho citace
	        inCTCV <= inCTCV +'1';					--vertikalni citac +1
	        if inCTCV=239 and SWITCH(0)='1' then
		    inPAGE <= not inPAGE;				--zmena zapisove stranky
		end if;
	    elsif inCTCH(1 downto 0)=0 then
		in3PIX(3 downto 0) <= RGBI;				--registruj 1 pixel do pomocneho registru
	    elsif  inCTCH(1 downto 0)=1 then
		in3PIX(7 downto 4) <= RGBI;				--registruj 2 pixel do pomocneho registru
	    elsif  inCTCH(1 downto 0)=2 then
		in3PIX(11 downto 8) <= RGBI;				--registruj 3 pixel do pomocneho registru
	    else
		inCTCH(8 downto 2) <= inCTCH(8 downto 2)+'1';		--nastav citac na dalsi ctverici pixelu
		in4PIX <= RGBI & in3PIX;				--registruj vsechny ctyri pixely
		wrREQ1 <= not inCTCV(8);				--nastav pozadavek o zapis
	    end if;
	end if;
    end if;
end process;
--============================================================================
--Vystupni cast vga
--============================================================================
process (CLK25) begin
    if CLK25'event and CLK25='1' then
	vgaDIV <= not vgaDIV;						--delicka kmitoctu (25/2=12,5MHz)	
	if vgaDIV='1' then						--podminka delicky kmitoctu
------------------------------------------------------------------------------
-- detekce zapisu do pameti RAM od vstupni casti a generovani zapisu do pameti RAM
------------------------------------------------------------------------------
	    wrREQ2 <= wrREQ1 & wrREQ2(1);				--registruj pozadavek o zapis ze vstupni casti
	    wrREQ3 <= '0';						--interni pozadavek zapisu je defaultne neaktivni
	    wrREQ4 <= '1';						--zapis je defaultne neaktivni
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
	    if vgaCTCH=396 then						--pokud jsme docitali sloupce na radku
		vgaCTCH <= (others=>'0');				--nulovani horizontalniho citace
		if vgaCTCV=524 then					--pokud jsme docitali radky na strance
		    vgaCTCV <= (others=>'0');				--nulovani vertikalniho citace
		    vgaPAGE <= not inPAGE;				--preklopeni do pameti do ktere se nezapisuje
		else
		    vgaCTCV <= vgaCTCV +'1';				--vertikalni citac +1
		end if;
	    else
		vgaCTCH <= vgaCTCH +'1';				--horizontalni citac +1
	    end if;
------------------------------------------------------------------------------
-- VGA - generovani vertikalni synchronizace
------------------------------------------------------------------------------
	    if vgaCTCV=0 then
		vgaENAv <= '1';						--povoleni zobrazeni
	    elsif vgaCTCV=480 then
		vgaENAv <= '0';						--zakazani zobrazeni
	    elsif vgaCTCV=490 then
		VGAVSYNC <= '0';					--zacatek vertikalni synchronizace
	    elsif vgaCTCV=492 then
		VGAVSYNC <= '1';					--konec vertikalni synchronizace
--############################################################################
--## Funkce pro nastaveni obrazu na stred				    ##
--elsif vgaCTCV=432 then
--vgaBENv <= '1';	--povoleni zobrazeni borderu od vertikalniho citace
--elsif vgaCTCV=48 then
--vgaBENv <= '0';	--zakazani zobrazeni borderu od vertikalniho citace
--############################################################################
	    end if;
------------------------------------------------------------------------------
-- VGA - generovani horizontalni synchronizace
------------------------------------------------------------------------------
	    if vgaCTCH=3 and vgaENAv='1' then
		vgaENAB <= '1';						--povoleni zobrazovani
	    elsif vgaCTCH=323 then
		vgaENAB <= '0';						--zakazani zobrazovani
	    elsif vgaCTCH=331 then
		VGAHSYNC <= '0';					--zacatek horizontalni synchronizace
	    elsif vgaCTCH=377 then
		VGAHSYNC <= '1';					--konec horizontalni synchronizace
--############################################################################
--## Funkce pro nastaveni obrazu na stred				    ##
--elsif vgaCTCH=295 then
--vgaBENA <= '1';	--povoleni zobrazovani borderu
--elsif vgaCTCH=39 and vgaBENv='0' then
--vgaBENA <= '0';	--zakazani zobrazovani borderu
--############################################################################
	    end if;
------------------------------------------------------------------------------
-- VGA - cteni dat z pameti a jejich zapis do registru, rotace registru
------------------------------------------------------------------------------
	    if vgaCTCH(1 downto 0)=3 then
		vga4PIX <= RAMDAT;					--zapis prectenych dat z pameti do registru
	    else
		vga4PIX <= "0000" & vga4PIX(15 downto 4);		--posunuti registru o ctyri bity = dalsi pixel
	    end if;
------------------------------------------------------------------------------
	end if;
    end if;
end process;
------------------------------------------------------------------------------
-- VGA - generovani signalu pro barvy
------------------------------------------------------------------------------
vgaPIX <=  "0000" when vgaENAB='0' else					--zobrazovani zakazano
	   "1111" when vga4PIX(2 downto 0)=0 and SWITCH(1)='0' else	--nastavi intensitu u cerne barvy (pri inverzi)
	   "0000" when vga4PIX(2 downto 0)=0 and SWITCH(1)='1' else	--zrusi intensitu u cerne barvy (bez inverze)
	   not vga4PIX(3 downto 0) when SWITCH(1)='0' else		--barvy s inverzi
	   vga4PIX(3 downto 0);						--barvy bez inverze
--############################################################################
--## Funkce pro nastaveni obrazu na stred				    ##
--vgaINT <=  vgaBENA when vgaENAB='1' and SWITCH(3 downto 1)="111" else '0';
--############################################################################
vgaINT <=  '0' when vgaPIX(3 downto 0)=0 else				--nepouzije se nikdy na cernou barvu (ani pri zatemneni)
	   '0' when SWITCH(3 downto 2)=3 else				--nepouzije se pokud jsou jeji funce zakazany
	   '0' when SWITCH(3 downto 2)=2 and vgaCTCV(0)='1' else	--nepouzije se u scanlines na kazdem lichem radku
	   '0' when SWITCH(3 downto 2)=1 and vgaPIX(3)='1' else		--nepouzije se u modu 1 pri aktivni intensite
	   '1';
VGARED1 <= vgaPIX(0);							--cervena slozka vysoka intenzita
VGARED2 <= '0' when SWITCH(3 downto 2)=2 and vgaCTCV(0)='1' else	--cervena slozka stredni intenzita
	   vgaPIX(3) when vgaPIX(2 downto 0)=0 else
	   vgaPIX(3) and vgaPIX(0);
VGARED3 <= vgaINT;							--cervena slozka nizka intenzita
VGAGRN1 <= vgaPIX(1);							--zelena slozka vysoka intenzita
VGAGRN2 <= '0' when SWITCH(3 downto 2)=2 and vgaCTCV(0)='1' else	--zelena slozka stredni intenzita
	   vgaPIX(3) when vgaPIX(2 downto 0)=0 else
	   vgaPIX(3) and vgaPIX(1);
VGAGRN3 <= vgaINT;							--zelena slozka nizka intenzita
VGABLU1 <= vgaPIX(2);							--modra slozka vysoka intenzita
VGABLU2 <= '0' when SWITCH(3 downto 2)=2 and vgaCTCV(0)='1' else	--modra slozka stredni intenzita
	   vgaPIX(3) when vgaPIX(2 downto 0)=0 else
	   vgaPIX(3) and vgaPIX(2);
VGABLU3 <= vgaINT;							--modra slozka nizka intenzita
--============================================================================
-- napojeni pameti RAM
--============================================================================
RAMADR <=  "00" & inPAGE & inCTCV(7 downto 0) & inCTCH(8 downto 2) when wrREQ4='0' else
	   "00" & vgaPAGE & vgaCTCV(8 downto 1) & vgaCTCH(8 downto 2);
RAMDAT <=  in4PIX when wrREQ4='0' else "ZZZZZZZZZZZZZZZZ";
RAMWRT <=  wrREQ4;
------------------------------------------------------------------------------
end rtl;
