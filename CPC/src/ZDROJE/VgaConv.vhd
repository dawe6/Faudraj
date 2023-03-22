--============================================================================
--== CPC464, CPC664, CPC6128 Vga konvertor pro hardware Faudraj 3.1	    ==
--============================================================================
--== verze h31.f2.14						  © DL 2013 ==
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
-- vnejsi piny pro pripojeni k CPC
------------------------------------------------------------------------------
RGB		: in std_logic_vector(5 downto 0);			--barevne slozky
HSYNC		: in std_logic;						--horizontalni synchronizace
VSYNC		: in std_logic;						--vertikalni synchronizace
CLK16		: in std_logic;						--hodiny 16MHz
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
signal inHSYNC	: std_logic;					--pamet stavu signalu HSYNC
signal inVSYNC	: std_logic;					--pamet stavu signalu VSYNC
signal inCTCH	: std_logic_vector(9 downto 0);			--horizontalni citac vstupniho obrazu
signal inCTCV	: std_logic_vector(8 downto 0);			--vertikalni citac vstupniho obrazu
signal inPAGE	: std_logic;					--vyber stranky do ktere se zapisuje
signal inPIX	: std_logic_vector(5 downto 0);			--pamet pro pixel na vstupu
signal in2PIX	: std_logic_vector(11 downto 0);		--pamet pro 2 pixely na vstupu (slovo pro zapis do RAM)
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
signal vga2PIX	: std_logic_vector(11 downto 0);			--pamet pro 2 pixely na vystupu (slovo prectene z RAM)
signal vgaPIX	: std_logic_vector(5 downto 0);				--barevny vystup jeden pixel
signal vgaINT	: std_logic;						--pomocna barevna intenzita
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
--Vstupni cast od CPC
--============================================================================
process (CLK16) begin
    if CLK16'event and CLK16='1' then
	inHSYNC <= HSYNC;					--pamet stavu HSYNC
	inVSYNC <= VSYNC;					--pamet stavu VSYNC
	wrREQ1 <= '0';						--pozadavek o zapis je defaultne neaktivni
	if inVSYNC='0' and VSYNC='1' then			--detekovana nabezna hrana VSYNC
	    inCTCV <= "111010100";				--inicializace vertikalniho citace (-/+ obraz nahoru/dolu)
	    if SWITCH(3)='1' then				--pouze pokud neni stop stav
	 	inPAGE <= not inPAGE;				--preklopeni do druhe poloviny pameti
	    end if;
	elsif inHSYNC='0' and HSYNC='1' then			--detekovana nabezna hrana HSYNC
	    inCTCH <= "1100100111";				--inicializace horizontalniho citace (-/+ obraz vlevo/vpravo)
	    inCTCV <= inCTCV + 1;				--vertikalni citac +1
	elsif inCTCH(0)='0' then
	    inPIX <= RGB;					--registruj prvni pixel
	    inCTCH(0) <= '1';					--citac na dalsi pixel
	else
	    in2PIX <= RGB & inPIX;				--registruj vsechny ctyri pixely
	    inCTCH <= inCTCH + '1';				--citac na dalsi pixel
	    wrREQ1 <= not inCTCV(8);				--nastav pozadavek o zapis
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
------------------------------------------------------------------------------
-- detekce zapisu do pameti RAM od vstupni casti a generovani zapisu do pameti RAM
------------------------------------------------------------------------------
	wrREQ2 <= wrREQ1 & wrREQ2(1);					--registruj pozadavek o zapis ze vstupni casti
	wrREQ3 <= '0';							--interni pozadavek zapisu je defaultne neaktivni
	wrREQ4 <= '1';							--zapis je defaultne neaktivni
	if wrREQ2="10" or wrREQ3='1' then				--je detekovan pozadavek o zapis?
	    if vgaCTCH(0)='1' then					--je mozne zapis provest?
		wrREQ4 <= '0';						--nastav vnitrni signal /WR
	    else							--pokud ho nelze vykonat
		wrREQ3 <= '1';						--nastav interni pozadavek o zapis
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
	if vgaCTCV=622 then
	    vgaENAv <= '1';						--povoleni zobrazeni
	elsif vgaCTCV=556 then
	    vgaENAv <= '0';						--zakazani zobrazeni
	elsif vgaCTCV=593 then
	    VGAVSYNC <= '1';						--zacatek vertikalni synchronizace
	elsif vgaCTCV=599 then
	    VGAVSYNC <= '0';						--konec vertikalni synchronizace
--############################################################################
--## Funkce pro nastaveni obrazu na stred				    ##
--elsif vgaCTCV=456 then
--vgaBENv <= '1';	--povoleni zobrazeni borderu od vertikalniho citace
--elsif vgaCTCV=56 then
--vgaBENv <= '0';	--zakazani zobrazeni borderu od vertikalniho citace
--############################################################################
	end if;
------------------------------------------------------------------------------
-- VGA - generovani horizontalni synchronizace
------------------------------------------------------------------------------
	if vgaCTCH=7 and vgaENAv='1' then
	    vgaENAB <= '1';						--povoleni zobrazovani
	elsif vgaCTCH=807 then		--801
	    vgaENAB <= '0';						--zakazani zobrazovani
	elsif vgaCTCH=863 then		--857
	    VGAHSYNC <= '1';						--zacatek horizontalni synchronizace
	elsif vgaCTCH=983 then		--977
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
	if vgaCTCH(0)='1' then
	    vga2PIX <= RAMDAT(11 downto 0);				--zapis prectenych dat z pameti do registru
	else
	    vga2PIX(5 downto 0) <= vga2PIX(11 downto 6);		--posunuti registru na dalsi pixel
	end if;
------------------------------------------------------------------------------
    end if;
end process;
------------------------------------------------------------------------------
-- VGA - generovani signalu pro barvy
------------------------------------------------------------------------------
vgaPIX  <= "000000" when vgaENAB='0' else				--zobrazovani zakazano
	   vga2PIX(5 downto 0);						--barvy pixelu
--############################################################################
--## Funkce pro nastaveni obrazu na stred				    ##
--vgaINT <= vgaBENA when vgaENAB='1' and SWITCH(3 downto 0)=15 else '0';
--############################################################################
vgaINT  <= '0' when vgaPIX=0 else					--nepouzije se pri cerne barve a pri zatemneni
	   '0' when SWITCH(2)='1' else					--nepouzije se pokud jsou scanlines zakazany
	   '0' when vgaCTCV(0)='1' else					--nepouzije se u scanlines na kazdem lichem radku
	   '1';
VGARED1 <= vgaPIX(0);
VGARED2 <= '0' when SWITCH(2)='0' and vgaCTCV(0)='1' else
	   vgaPIX(1);
VGARED3 <= vgaINT;
VGAGRN1 <= vgaPIX(2);
VGAGRN2 <= '0' when SWITCH(2)='0' and vgaCTCV(0)='1' else
	   vgaPIX(3);
VGAGRN3 <= vgaINT;
VGABLU1 <= vgaPIX(4);
VGABLU2 <= '0' when SWITCH(2)='0' and vgaCTCV(0)='1' else
	   vgaPIX(5);
VGABLU3 <= vgaINT;
--============================================================================
-- napojeni pameti RAM
--============================================================================
RAMADR <= inPAGE & inCTCV(7 downto 0) & inCTCH(9 downto 1) when wrREQ4='0' else		-- cpc zapis
	  vgaPAGE & "00000000" & vgaCTCH(9 downto 1) when vgaCTCV(9 downto 8)=3 else	-- vga cteni falesne horni
	  vgaPAGE & "11111111" & vgaCTCH(9 downto 1) when vgaCTCV(9 downto 8)=2 else	-- vga cteni falesne dolni
	  vgaPAGE & vgaCTCV(8 downto 1) & vgaCTCH(9 downto 1);				-- vga cteni
RAMDAT <= "0000" & in2PIX when wrREQ4='0' else "ZZZZZZZZZZZZZZZZ";
RAMWRT <= wrREQ4;
-----------------------------------------------------------------------------
end rtl;
