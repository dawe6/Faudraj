--============================================================================
--== ULA48k Vga konvertor pro hardware Faudraj 3.1			    ==
--============================================================================
--== verze h31.f3.51						  © DL 2013 ==
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
-- vnejsi piny pro pripojeni k ULA48
------------------------------------------------------------------------------
ULADT		: in std_logic_vector(7 downto 0);			--datova sbernice ULA48k
IOULA		: in std_logic;						--nI/O operace pro ULA48k
WRULA		: in std_logic;						--nWR operace pro ULA48k
UINTR		: in std_logic;						--preruseni z ULA48k
CLK14		: in std_logic;						--hodiny 14MHz
OINTR		: inout std_logic;					--preruseni (vystup)
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
signal rUINTR	: std_logic;						--pamet stavu signalu UINTR
signal rULAWR	: std_logic;						--pamet stavu signalu inULAWR
signal inULAWR	: std_logic;						--ULAWR
signal inBORD	: std_logic_vector(2 downto 0);				--register barvy borderu
signal inFLSH	: std_logic_vector(4 downto 0);				--citac blikani (FLASH)
signal inCTCH	: std_logic_vector(9 downto 0);				--horizontalni citac vstupniho obrazu
signal inCTCV	: std_logic_vector(8 downto 0);				--vertikalni citac vstupniho obrazu
signal inBORh	: std_logic;						--border od horizontalniho citace
signal inBORv	: std_logic;						--border od vertikalniho citace
signal inDATA	: std_logic_vector(15 downto 0);			--register 15-ti bitoveho slova pro zapis do RAM
------------------------------------------------------------------------------
-- vnitrni signaly pro zapis do pameti RAM
------------------------------------------------------------------------------
signal wrREQ1	: std_logic;						--pozadavek zapisu ze vstupni casti
signal wrREQ2	: std_logic_vector(1 downto 0);				--register pozadavku zapisu ze vstupni casti
signal wrREQ3	: std_logic;						--pamet pozadavku zapisu pro VGA cast
signal wrREQ4	: std_logic;						--interni signal WR pro pamet RAM
signal inADR	: std_logic_vector(5 downto 0);				--register casti zapisove adresy
------------------------------------------------------------------------------
-- vnitrni signaly pro VGA cast
------------------------------------------------------------------------------
signal vgaCTCH	: std_logic_vector(9 downto 0);				--VGA horizontalni citac
signal vgaCTCV	: std_logic_vector(9 downto 0);				--VGA vertikalni citac
signal vgaENAB	: std_logic;						--povoleni zobrazeni
signal vgaENAv	: std_logic;						--povoleni zobrazeni od vertikalniho citace
signal vgaBENA	: std_logic;						--povoleni zobrazeni borderu
signal vgaBENv	: std_logic;						--povoleni zobrazeni borderu od vertikalniho citace
signal vgaPAGE	: std_logic;						--vyber stranky ze ktere se zobrazuje
signal vgaDATA	: std_logic_vector(15 downto 0);			--pamet pro slovo prectene z RAM
signal vgaPIX	: std_logic_vector(3 downto 0);				--barevny vystup - upravy barev
signal vgaINT	: std_logic;						--pomocna barevna intenzita
------------------------------------------------------------------------------
begin
--============================================================================
--Vstupni cast od ULA48k
--============================================================================
OINTR <= '0' when UINTR='0' else 'Z';					--vystup signalu preruseni
inULAWR <= IOULA or WRULA;						--zapis do ULA
process (CLK14) begin
    if CLK14'event and CLK14='1' then
	rUINTR <= UINTR;						--pamet stavu UINTR
	rULAWR <= inULAWR;						--pamet stavu inULAWR
	wrREQ1 <= '0';							--pozadavek o zapis je defaultne neaktivni
	inCTCH <= inCTCH + '1';						--horizontalni citac +1
------------------------------------------------------------------------------
	if rULAWR='0' and inULAWR='1' then				--detekovana sestupna hrana ULAWR
	    inBORD <= ULADT(2 downto 0);				--zapis do registru borderu
	end if;
------------------------------------------------------------------------------
	if rUINTR='1' and UINTR='0' then				--detekovana sestupna hrana UINTR
	    inCTCH <= "0001010000";					--inicializace horizontalniho citace
	    inCTCV <= "111011000";					--inicializace vertikalniho citace
	    if SWITCH(3)='1' then
	 	inFLSH <= inFLSH + '1';					--citac blikani (FLASH) +1
	    end if;
	elsif inCTCH=895 then						--pokud jsme docitali sloupce na radku
	    inCTCH <= (others=>'0');					--nulovani horizontalniho citace
	    inCTCV <= inCTCV + '1';					--vertikalni citac +1
	end if;
------------------------------------------------------------------------------
	if inBORh='1' or inBORv='1' then				--test na border
	    if inCTCH(3 downto 0)=0 then
		inDATA(14 downto 8) <= '0' & inBORD & inBORD;		--barva borderu
		wrREQ1 <= '1';						--nastav pozadavek o zapisnot inCTCV(8);
		inADR <= inCTCH(9 downto 4);				--registruj cast zapisove adresy
	    end if;
	elsif inCTCH(4)='0' and inCTCH(1 downto 0)=0 then
	    if inCTCH(2)='0' then 
		inDATA(7 downto 0) <= ULADT;				--registruj bajt pixelu na vstupu
	    else
		inDATA(15 downto 8) <= (ULADT(7) and inFLSH(4)) & ULADT(6 downto 0);	--registruj atributy na vstupu
		wrREQ1 <= '1';						--nastav pozadavek o zapis
		inADR <= inCTCH(9 downto 5) & inCTCH(3);		--registruj cast zapisove adresy
	    end if;
	end if;
------------------------------------------------------------------------------
	if inCTCV=24 then
	    inBORv <= '0';						--konec borderu (vertikalni citac)
	elsif inCTCV=216 then
	    inBORv <= '1';						--zacatek borderu (vertikalni citac)
	end if;
	if inCTCH=82 then
	    inBORh <= '0';						--konec borderu (horizontalni citac)
	elsif inCTCH=594 then
	    inBORh <= '1';						--zacatek borderu (horizontalni citac)
	end if;
------------------------------------------------------------------------------
    end if;
end process;
--============================================================================
--Vystupni cast vga
--============================================================================
process (CLK25) begin
    if CLK25'event and CLK25='1' then
------------------------------------------------------------------------------
-- detekce zapisu do pameti RAM od vstupni casti a generovani zapisu do pameti RAM
------------------------------------------------------------------------------
	wrREQ2 <= wrREQ1 & wrREQ2(1);					--registruj pozadavek o zapis ze vstupni casti
	wrREQ3 <= '0';							--interni pozadavek zapisu je defaultne neaktivni
	wrREQ4 <= '1';							--zapis je defaultne neaktivni
	if wrREQ2="01" or wrREQ3='1' then				--je detekovan pozadavek o zapis?
	    if vgaCTCH(3 downto 0)/=14 then				--je mozne zapis provest?
		wrREQ4 <= '0';						--nastav vnitrni signal /WR
	    else							--pokud ho nelze vykonat
		wrREQ3 <= '1';						--nastav interni pozadavek o zapis
	    end if;
	end if;
------------------------------------------------------------------------------
-- VGA - citani, nulovani horizontalniho a vertikalniho citace
------------------------------------------------------------------------------
	if vgaCTCH=793 then						--pokud jsme docitali sloupce na radku
	    vgaCTCH <= (others=>'0');					--nulovani horizontalniho citace
	    if vgaCTCV=524 then						--pokud jsme docitali radky na strance
		vgaCTCV <= (others=>'0');				--nulovani vertikalniho citace
		vgaPAGE <= not inFLSH(0);				--preklopeni do pameti do ktere se nezapisuje
	    else
		vgaCTCV <= vgaCTCV +'1';				--vertikalni citac +1
	    end if;
	else
	    vgaCTCH <= vgaCTCH +'1';					--horizontalni citac +1
	end if;
------------------------------------------------------------------------------
-- VGA - generovani vertikalni synchronizace
------------------------------------------------------------------------------
	if vgaCTCV=0 then
	    vgaENAv <= '1';						--povoleni zobrazeni
	elsif vgaCTCV=48 then
	    vgaBENv <= '0';						--zakazani zobrazeni borderu od vertikalniho citace
	elsif vgaCTCV=432 then
	    vgaBENv <= '1';						--povoleni zobrazeni borderu od vertikalniho citace
	elsif vgaCTCV=480 then
	    vgaENAv <= '0';						--zakazani zobrazeni
	elsif vgaCTCV=490 then
	    VGAVSYNC <= '0';						--zacatek vertikalni synchronizace
	elsif vgaCTCV=492 then
	    VGAVSYNC <= '1';						--konec vertikalni synchronizace
	end if;
------------------------------------------------------------------------------
-- VGA - generovani horizontalni synchronizace
------------------------------------------------------------------------------
	if vgaCTCH=39 and vgaENAv='1' then
	    vgaENAB <= '1';						--povoleni zobrazovani
	elsif vgaCTCH=111 and vgaBENv='0' then
	    vgaBENA <= '0';						--zakazani zobrazovani borderu
	elsif vgaCTCH=623 then
	    vgaBENA <= '1';						--povoleni zobrazovani borderu
	elsif vgaCTCH=679 then
	    vgaENAB <= '0';						--zakazani zobrazovani
	elsif vgaCTCH=703 then
	    VGAHSYNC <= '0';						--zacatek horizontalni synchronizace
	elsif vgaCTCH=787 then
	    VGAHSYNC <= '1';						--konec horizontalni synchronizace
	end if;
------------------------------------------------------------------------------
-- VGA - cteni dat z pameti a jejich zapis do registru, rotace registru
------------------------------------------------------------------------------
	if vgaCTCH(3 downto 0)=15 then
	    vgaDATA <= RAMDAT;						--zapis prectenych dat z pameti do registru
	elsif vgaCTCH(0)='1' then
	    vgaDATA(7 downto 1) <= vgaDATA(6 downto 0);			--posunuti registru pixelu
	end if;
------------------------------------------------------------------------------
    end if;
end process;
------------------------------------------------------------------------------
-- VGA - generovani signalu pro barvy
------------------------------------------------------------------------------
vgaPIX  <= "0000" when vgaENAB='0' else					--zobrazovani zakazano
	   vgaDATA(14) & vgaDATA(10 downto 8) when			--barva popredi (pixel je)
				(vgaDATA(7) xor vgaDATA(15))='1' else	--test na pixel nebo blikani
	   vgaDATA(14) & vgaDATA(13 downto 11);				--barva pozadi (pixel neni)
--############################################################################
--## Funkce pro nastaveni obrazu na stred				    ##
--vgaINT  <= '0' when vgaENAB='0' and SWITCH(3 downto 1)="111" else '0';
--############################################################################
vgaINT <=  '0' when vgaPIX(2 downto 0)=0 else				--nepouzije se nikdy na cernou barvu (ani pri zatemneni)
	   '0' when SWITCH(2)='1' else					--nepouzije se pokud jsou jeji funce zakazany
	   '0' when vgaCTCV(0)='1' else '1';				--nepouzije se u scanlines na kazdem lichem radku
VGARED1 <= vgaPIX(1);							--cervena slozka vysoka intenzita
VGARED2 <= vgaPIX(3) and vgaPIX(1);
VGARED3 <= vgaINT;							--cervena slozka nizka intenzita
VGAGRN1 <= vgaPIX(2);							--zelena slozka vysoka intenzita
VGAGRN2 <= vgaPIX(3) and vgaPIX(2);
VGAGRN3 <= vgaINT;							--zelena slozka nizka intenzita
VGABLU1 <= vgaPIX(0);							--modra slozka vysoka intenzita
VGABLU2 <= vgaPIX(3) and vgaPIX(0);
VGABLU3 <= vgaINT;							--modra slozka nizka intenzita
--============================================================================
-- napojeni pameti RAM
--============================================================================
RAMADR <=  "000" & inFLSH(0) & inCTCV(7 downto 0) & inADR when wrREQ4='0' else
	   "000" & vgaPAGE & vgaCTCV(8 downto 1) & vgaCTCH(9 downto 4);
RAMDAT <=  inDATA when wrREQ4='0' else "ZZZZZZZZZZZZZZZZ";
RAMWRT <=  wrREQ4;
------------------------------------------------------------------------------
end rtl;
