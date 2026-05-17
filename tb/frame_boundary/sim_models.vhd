library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity main_fifo is
    port (
        clock : in  std_logic;
        data  : in  std_logic_vector(39 downto 0);
        rdreq : in  std_logic;
        sclr  : in  std_logic;
        wrreq : in  std_logic;
        empty : out std_logic;
        full  : out std_logic;
        q     : out std_logic_vector(39 downto 0);
        usedw : out std_logic_vector(12 downto 0)
    );
end entity main_fifo;

architecture sim of main_fifo is
    constant DEPTH_CONST : natural := 8192;
    type mem_t is array (0 to DEPTH_CONST-1) of std_logic_vector(39 downto 0);
    signal mem    : mem_t := (others => (others => '0'));
    signal rd_ptr : natural range 0 to DEPTH_CONST-1 := 0;
    signal wr_ptr : natural range 0 to DEPTH_CONST-1 := 0;
    signal count  : natural range 0 to DEPTH_CONST := 0;
begin
    empty <= '1' when count = 0 else '0';
    full  <= '1' when count = DEPTH_CONST else '0';
    q     <= mem(rd_ptr) when count /= 0 else (others => '0');
    usedw <= std_logic_vector(to_unsigned(count, usedw'length));

    process (clock)
        variable do_wr : boolean;
        variable do_rd : boolean;
    begin
        if rising_edge(clock) then
            if sclr = '1' then
                rd_ptr <= 0;
                wr_ptr <= 0;
                count  <= 0;
            else
                do_wr := wrreq = '1' and count < DEPTH_CONST;
                do_rd := rdreq = '1' and count > 0;

                if do_wr then
                    mem(wr_ptr) <= data;
                    if wr_ptr = DEPTH_CONST-1 then
                        wr_ptr <= 0;
                    else
                        wr_ptr <= wr_ptr + 1;
                    end if;
                end if;

                if do_rd then
                    if rd_ptr = DEPTH_CONST-1 then
                        rd_ptr <= 0;
                    else
                        rd_ptr <= rd_ptr + 1;
                    end if;
                end if;

                if do_wr and not do_rd then
                    count <= count + 1;
                elsif do_rd and not do_wr then
                    count <= count - 1;
                end if;
            end if;
        end if;
    end process;
end architecture sim;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alt_scfifo_w40d8 is
    port (
        clock : in  std_logic;
        data  : in  std_logic_vector(39 downto 0);
        rdreq : in  std_logic;
        sclr  : in  std_logic;
        wrreq : in  std_logic;
        empty : out std_logic;
        full  : out std_logic;
        q     : out std_logic_vector(39 downto 0);
        usedw : out std_logic_vector(2 downto 0)
    );
end entity alt_scfifo_w40d8;

architecture sim of alt_scfifo_w40d8 is
    constant DEPTH_CONST : natural := 8;
    type mem_t is array (0 to DEPTH_CONST-1) of std_logic_vector(39 downto 0);
    signal mem    : mem_t := (others => (others => '0'));
    signal rd_ptr : natural range 0 to DEPTH_CONST-1 := 0;
    signal wr_ptr : natural range 0 to DEPTH_CONST-1 := 0;
    signal count  : natural range 0 to DEPTH_CONST := 0;
begin
    empty <= '1' when count = 0 else '0';
    full  <= '1' when count = DEPTH_CONST else '0';
    q     <= mem(rd_ptr) when count /= 0 else (others => '0');
    usedw <= std_logic_vector(to_unsigned(count, usedw'length)) when count < DEPTH_CONST else (others => '1');

    process (clock)
        variable do_wr : boolean;
        variable do_rd : boolean;
    begin
        if rising_edge(clock) then
            if sclr = '1' then
                rd_ptr <= 0;
                wr_ptr <= 0;
                count  <= 0;
            else
                do_wr := wrreq = '1' and count < DEPTH_CONST;
                do_rd := rdreq = '1' and count > 0;

                if do_wr then
                    mem(wr_ptr) <= data;
                    if wr_ptr = DEPTH_CONST-1 then
                        wr_ptr <= 0;
                    else
                        wr_ptr <= wr_ptr + 1;
                    end if;
                end if;

                if do_rd then
                    if rd_ptr = DEPTH_CONST-1 then
                        rd_ptr <= 0;
                    else
                        rd_ptr <= rd_ptr + 1;
                    end if;
                end if;

                if do_wr and not do_rd then
                    count <= count + 1;
                elsif do_rd and not do_wr then
                    count <= count - 1;
                end if;
            end if;
        end if;
    end process;
end architecture sim;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alt_dcfifo_w40d256_patched is
    port (
        aclr    : in  std_logic := '0';
        data    : in  std_logic_vector(39 downto 0);
        rdclk   : in  std_logic;
        rdreq   : in  std_logic;
        wrclk   : in  std_logic;
        wrreq   : in  std_logic;
        q       : out std_logic_vector(39 downto 0);
        rdempty : out std_logic;
        rdfull  : out std_logic;
        rdusedw : out std_logic_vector(9 downto 0);
        wrempty : out std_logic;
        wrfull  : out std_logic;
        wrusedw : out std_logic_vector(9 downto 0)
    );
end entity alt_dcfifo_w40d256_patched;

architecture sim of alt_dcfifo_w40d256_patched is
    constant DEPTH_CONST : natural := 512;
    type mem_t is array (0 to DEPTH_CONST-1) of std_logic_vector(39 downto 0);
    signal mem    : mem_t := (others => (others => '0'));
    signal rd_ptr : natural range 0 to DEPTH_CONST-1 := 0;
    signal wr_ptr : natural range 0 to DEPTH_CONST-1 := 0;
    signal count  : natural range 0 to DEPTH_CONST := 0;
begin
    rdempty <= '1' when count = 0 else '0';
    wrempty <= '1' when count = 0 else '0';
    rdfull  <= '1' when count = DEPTH_CONST else '0';
    wrfull  <= '1' when count = DEPTH_CONST else '0';
    q       <= mem(rd_ptr) when count /= 0 else (others => '0');
    rdusedw <= std_logic_vector(to_unsigned(count, rdusedw'length)) when count < DEPTH_CONST else (others => '1');
    wrusedw <= std_logic_vector(to_unsigned(count, wrusedw'length)) when count < DEPTH_CONST else (others => '1');

    process (wrclk, aclr)
        variable do_wr : boolean;
        variable do_rd : boolean;
    begin
        if aclr = '1' then
            rd_ptr <= 0;
            wr_ptr <= 0;
            count  <= 0;
        elsif rising_edge(wrclk) then
            do_wr := wrreq = '1' and count < DEPTH_CONST;
            do_rd := rdreq = '1' and count > 0;

            if do_wr then
                mem(wr_ptr) <= data;
                if wr_ptr = DEPTH_CONST-1 then
                    wr_ptr <= 0;
                else
                    wr_ptr <= wr_ptr + 1;
                end if;
            end if;

            if do_rd then
                if rd_ptr = DEPTH_CONST-1 then
                    rd_ptr <= 0;
                else
                    rd_ptr <= rd_ptr + 1;
                end if;
            end if;

            if do_wr and not do_rd then
                count <= count + 1;
            elsif do_rd and not do_wr then
                count <= count - 1;
            end if;
        end if;
    end process;
end architecture sim;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alt_dcfifo_w48d4 is
    port (
        aclr    : in  std_logic := '0';
        data    : in  std_logic_vector(47 downto 0);
        rdclk   : in  std_logic;
        rdreq   : in  std_logic;
        wrclk   : in  std_logic;
        wrreq   : in  std_logic;
        q       : out std_logic_vector(47 downto 0);
        rdempty : out std_logic;
        wrfull  : out std_logic
    );
end entity alt_dcfifo_w48d4;

architecture sim of alt_dcfifo_w48d4 is
    signal q_r : std_logic_vector(47 downto 0) := (others => '0');
begin
    q       <= q_r;
    rdempty <= aclr;
    wrfull  <= '0';

    process (rdclk, aclr)
    begin
        if aclr = '1' then
            q_r <= (others => '0');
        elsif rising_edge(rdclk) then
            if rdreq = '1' and wrreq = '1' then
                q_r <= data;
            end if;
        end if;
    end process;
end architecture sim;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alt_parallel_add is
    port (
        clock  : in  std_logic := '0';
        data0x : in  std_logic_vector(47 downto 0);
        data1x : in  std_logic_vector(47 downto 0);
        data2x : in  std_logic_vector(47 downto 0);
        data3x : in  std_logic_vector(47 downto 0);
        result : out std_logic_vector(49 downto 0)
    );
end entity alt_parallel_add;

architecture sim of alt_parallel_add is
begin
    result <= std_logic_vector(
        resize(unsigned(data0x), result'length) +
        resize(unsigned(data1x), result'length) +
        resize(unsigned(data2x), result'length) +
        resize(unsigned(data3x), result'length)
    );
end architecture sim;
