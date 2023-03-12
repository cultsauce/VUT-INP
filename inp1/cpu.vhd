-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2022 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): jmeno <login AT stud.fit.vutbr.cz>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is
  signal pc_reg : std_logic_vector(12 downto 0);
  signal pc_inc : std_logic;
  signal pc_dec : std_logic;

  signal ptr_reg : std_logic_vector(12 downto 0);
  signal ptr_inc : std_logic;
  signal ptr_dec : std_logic;

  signal pc_abus: std_logic;

  signal acc_mx : std_logic_vector(7 downto 0);
  signal accmx_sel : std_logic_vector(1 downto 0);

  signal ptr_abus : std_logic;
  signal acc_inc : std_logic;
  signal acc_dec : std_logic;
  signal acc_dbus : std_logic;

  signal out_reg : std_logic_vector(7 downto 0);
  signal out_ld : std_logic;

  signal br_reg : std_logic_vector(7 downto 0);
  signal br_inc : std_logic;
  signal br_dec : std_logic;
  
  type FSMstate is (sidle, sfetch0, sfetch1, sdecode, shalt,
                    sptr_inc0, sptr_dec0, sval_inc0, sval_inc1, 
                    sval_dec0, sval_dec1, sprint0, sprint1, sprint2,
                    sload0, sload1, swhile_begin0, swhile_begin1, sdow_begin0, sdow_end0, sdow_end1, 
                    sskip0_fwd, sskip1_fwd, sskip0_rev, sskip1_rev, snop);

  signal pstate : FSMstate;
  signal nstate : FSMstate;

 
begin

  nsl: process (pstate, DATA_RDATA, IN_VLD, OUT_BUSY)
    begin
      -- INIT
      DATA_EN <= '0';
      IN_REQ <= '0';
      OUT_WE <= '0';
      DATA_RDWR <= '0';
  
      ptr_inc <= '0';
      ptr_dec <= '0';
      ptr_abus <= '0';
  
      pc_inc <= '0';
      pc_dec <= '0';
      pc_abus <= '0';
    
      accmx_sel <= "11";
      acc_inc <= '0';
      acc_dec <= '0';
      acc_dbus <= '0';

      out_ld <= '0';

      br_inc <= '0';
      br_dec <= '0';
      case pstate is
      
        when sidle =>
          nstate <= sfetch0;
  
        when sfetch0 =>
          pc_abus <= '1';
          DATA_EN <= '1';
          DATA_RDWR <= '0';
          nstate <= sdecode;

        when sdecode =>
          case (DATA_RDATA) is
            when X"3E" => nstate <= sptr_inc0;
            when X"3C" => nstate <= sptr_dec0;
            when X"2B" => nstate <= sval_inc0;
            when X"2D" => nstate <= sval_dec0;
            when X"5B" => nstate <= swhile_begin0;
            when X"5D" => nstate <= sdow_end0;
            when X"28" => nstate <= sdow_begin0;
            when X"29" => nstate <= sdow_end0;
            when X"2E" => nstate <= sprint0;
            when X"2C" => nstate <= sload0;
            when X"00" => nstate <= shalt;
            when others => nstate <= snop;
          end case;
  
        when sptr_inc0 =>
          ptr_inc <= '1';
          pc_inc <= '1';
          nstate <= sfetch0;
  
        when sptr_dec0 =>
          ptr_dec <= '1';
          pc_inc <= '1';
          nstate <= sfetch0;
  
        when sval_inc0 =>
          ptr_abus <= '1';
          DATA_EN <= '1';
          DATA_RDWR <= '0';
          nstate <= sval_inc1;
  
        when sval_inc1 =>
          accmx_sel <= "01";
          acc_dbus <= '1';
          ptr_abus <= '1';
          DATA_EN <= '1';
          DATA_RDWR <= '1';
          pc_inc <= '1';
          nstate <= sfetch0;
  
        when sval_dec0 =>
          ptr_abus <= '1';
          DATA_EN <= '1';
          DATA_RDWR <= '0';
          nstate <= sval_dec1;
  
        when sval_dec1 =>
          accmx_sel <= "10";
          acc_dbus <= '1';
          ptr_abus <= '1';
          DATA_EN <= '1';
          DATA_RDWR <= '1';
          pc_inc <= '1';
          nstate <= sfetch0;
  
        when sprint0 =>
          DATA_EN <= '1';
          DATA_RDWR <= '0';
          ptr_abus <= '1';
          nstate <= sprint1;
        when sprint1 =>
          out_ld <= '1';
          nstate <= sprint2;

        when sprint2 =>
          if (OUT_BUSY='0') then        
            OUT_DATA <= out_reg;
            OUT_WE <= '1';
            pc_inc <= '1';
            nstate <= sfetch0;
          else 
            nstate <= sprint1;
          end if;
  
        when sload0 =>
          IN_REQ <= '1';
          nstate <= sload1;
  
        when sload1 =>
          IN_REQ <= '1';
          if (IN_VLD='1') then
            ptr_abus <= '1';
            DATA_EN <= '1';
            DATA_RDWR <= '1';
            accmx_sel <= "00";
            acc_dbus <= '1';
            pc_inc <= '1';
            nstate <= sfetch0;
          else
            nstate <= sload1;
          end if;
       
        when sdow_begin0 =>
          pc_inc <= '1';
          nstate <= sfetch0;

        when sdow_end0 =>
          ptr_abus <= '1';
          DATA_EN <= '1';
          DATA_RDWR <= '0';
          nstate <= sdow_end1;

        when sdow_end1 =>
          if (DATA_RDATA = X"00") then
            pc_inc <= '1';
            nstate <= sfetch0;
          else
            pc_dec <= '1';
            nstate <= sskip0_rev;
          end if;
        
        when sskip0_rev =>
          pc_abus <= '1';
          DATA_EN <= '1';
          DATA_RDWR <= '0';
          nstate <= sskip1_rev;
        
        when sskip1_rev =>
          if (DATA_RDATA=X"5D" or DATA_RDATA=X"29") then
            br_inc <= '1';
            pc_dec <= '1';
            nstate <= sskip0_rev;
          elsif (DATA_RDATA=X"5B" or DATA_RDATA=X"28") then
            if (br_reg=X"00") then
              pc_inc <= '1';
              nstate <= sfetch0;
            else
              br_dec <= '1';
              pc_dec <= '1';
              nstate <= sskip0_rev;
            end if;
          else 
            pc_dec <= '1';
            nstate <= sskip0_rev;
          end if;

        when swhile_begin0 =>
          ptr_abus <= '1';
          DATA_EN <= '1';
          DATA_RDWR <= '0';
          nstate <= swhile_begin1;

        when swhile_begin1 =>
          if (DATA_RDATA = X"00") then
            pc_inc <= '1';
            nstate <= sskip0_fwd;
          else
            pc_inc <= '1';
            nstate <= sfetch0;
          end if;
        
        when sskip0_fwd => 
          pc_abus <= '1';
          DATA_EN <= '1';
          DATA_RDWR <= '0';
          nstate <= sskip1_fwd;

        when sskip1_fwd =>
          if (DATA_RDATA = X"5B" or DATA_RDATA = X"28") then
            pc_inc <= '1';
            nstate <= sskip0_fwd;
            br_inc <= '1';
          elsif (DATA_RDATA = X"5D" or DATA_RDATA = X"29") then
            if (br_reg = X"00") then
              pc_inc <= '1';
              nstate <= sfetch0;
            else
              pc_inc <= '1';
              br_dec <= '1';
              nstate <= sskip0_fwd;
            end if;
          else
            pc_inc <= '1';
            nstate <= sskip0_fwd;
          end if;
          

        when shalt =>
          nstate <= shalt;
  
        when others =>
          pc_inc <= '1';
          nstate <= sfetch0;
      end case;
    end process;

  -- Program Counter
  pc_cntr: process (RESET, CLK)
  begin
    if (RESET='1') then
      pc_reg <= (others=>'0');
    elsif (CLK'event) and (CLK='1') then
      if (pc_inc='1') then
        if (pc_reg="0111111111111") then
          pc_reg <= (others=>'0');
        else
          pc_reg <= pc_reg + 1;
        end if;
      elsif (pc_dec='1') then
        if (pc_reg="0000000000000") then
          pc_reg <= "0111111111111";
        else
          pc_reg <= pc_reg - 1;
        end if;
      end if;
    end if;
  end process;

  tmp: process (RESET, CLK) 
  begin
    if (RESET='1') then
      out_reg <= (others=>'0');
    elsif (CLK'event) and (CLK='1') then
      if (out_ld='1') then
        out_reg <= DATA_RDATA;
      end if;
    end if;
  end process;


  -- Tristate driver
  DATA_ADDR <= pc_reg when (pc_abus = '1') else (others => 'Z');

  ptr_cntr: process (RESET, CLK)
  begin
    if (RESET='1') then
      ptr_reg <= "1000000000000"; -- data starts from address 0x1000
    elsif (CLK'event) and (CLK='1') then
      if (ptr_inc='1') then
        if (ptr_reg="1111111111111") then
          ptr_reg <= "1000000000000";
        else
          ptr_reg <= ptr_reg + 1;
        end if;
      elsif (ptr_dec='1') then
        if (ptr_reg="1000000000000") then
          ptr_reg <= "1111111111111";
        else
          ptr_reg <= ptr_reg - 1;
        end if;
      end if;
    end if;
  end process;

  DATA_ADDR <= ptr_reg when (ptr_abus = '1') else (others => 'Z');

  -- ACC data multiplexor
  with accmx_sel select
    acc_mx <= IN_DATA when "00", (DATA_RDATA + 1) when "01", (DATA_RDATA - 1) when "10", (others => 'Z') when others;

  DATA_WDATA <= acc_mx when (acc_dbus = '1') else (others => 'Z');

    --Present State register
    pstatereg: process(RESET, CLK)
    begin
      if (RESET='1') then
        pstate <= sidle;
      elsif (CLK'event) and (CLK='1') then
        pstate <= nstate;
      end if;
    end process;
  
  
    --FSM next state logic,
    ---output logic  
    
  bracket_cntr_rev: process(RESET, CLK)
  begin
    if (RESET ='1') then
      br_reg <= (others=>'0');
    elsif (CLK'event) and (CLK='1') then
      if (br_inc='1') then
        br_reg <= br_reg + 1;
      elsif (br_dec='1') then
        br_reg <= br_reg - 1;
      end if;
    end if;
  end process; 
  
end behavioral;

