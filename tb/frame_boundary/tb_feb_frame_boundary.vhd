library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_feb_frame_boundary is
end entity tb_feb_frame_boundary;

architecture sim of tb_feb_frame_boundary is
    constant CLK_PERIOD_CONST        : time := 8 ns;
    constant EXPECTED_SUBH_CONST     : natural := 128;
    constant EXPECTED_FRAME_WORDS_CONST : natural := 5 + EXPECTED_SUBH_CONST + 1;
    constant EXPECTED_FRAME_TICKS_CONST : unsigned(47 downto 0) := to_unsigned(16#800#, 48);

    subtype hit_word_t is std_logic_vector(35 downto 0);
    type hit_word_array_t is array (0 to 3) of hit_word_t;
    type sl_array_t is array (0 to 3) of std_logic;

    signal clk_xcvr  : std_logic := '0';
    signal clk_data  : std_logic := '0';
    signal rst_xcvr  : std_logic := '1';
    signal rst_data  : std_logic := '1';

    signal lane_data  : hit_word_array_t := (others => (others => '0'));
    signal lane_valid : sl_array_t := (others => '0');
    signal lane_ready : sl_array_t;
    signal lane_sop   : sl_array_t := (others => '0');
    signal lane_eop   : sl_array_t := (others => '0');

    signal out_sop   : std_logic;
    signal out_eop   : std_logic;
    signal out_data  : std_logic_vector(35 downto 0);
    signal out_valid : std_logic;
    signal out_ready : std_logic := '1';

    signal ctrl_d_data  : std_logic_vector(8 downto 0) := (others => '0');
    signal ctrl_d_valid : std_logic := '0';
    signal ctrl_d_ready : std_logic;
    signal ctrl_x_data  : std_logic_vector(8 downto 0) := (others => '0');
    signal ctrl_x_valid : std_logic := '0';
    signal ctrl_x_ready : std_logic;

    signal csr_readdata    : std_logic_vector(31 downto 0);
    signal csr_read        : std_logic := '0';
    signal csr_address     : std_logic_vector(3 downto 0) := (others => '0');
    signal csr_waitrequest : std_logic;
    signal csr_write       : std_logic := '0';
    signal csr_writedata   : std_logic_vector(31 downto 0) := (others => '0');

    signal debug_ts_data          : std_logic_vector(15 downto 0);
    signal debug_ts_valid         : std_logic;
    signal debug_burst_data       : std_logic_vector(15 downto 0);
    signal debug_burst_valid      : std_logic;
    signal ts_delta_data          : std_logic_vector(15 downto 0);
    signal ts_delta_valid         : std_logic;
    signal debug_filllevel_data   : std_logic_vector(15 downto 0);
    signal debug_filllevel_valid  : std_logic;
    signal debug_loss8fill_data   : std_logic_vector(15 downto 0);
    signal debug_loss8fill_valid  : std_logic;
    signal debug_delay8loss_data  : std_logic_vector(15 downto 0);
    signal debug_delay8loss_valid : std_logic;

    signal done : std_logic := '0';

    function make_subheader(ts : natural) return hit_word_t is
        variable word_v : hit_word_t := (others => '0');
    begin
        word_v(35 downto 32) := "0001";
        word_v(31 downto 24) := std_logic_vector(to_unsigned(ts mod 256, 8));
        word_v(15 downto 8)  := (others => '0');
        word_v(7 downto 0)   := x"F7";
        return word_v;
    end function;

begin
    clk_xcvr <= not clk_xcvr after CLK_PERIOD_CONST / 2;
    clk_data <= not clk_data after CLK_PERIOD_CONST / 2;

    dut : entity work.feb_frame_assembly
        generic map (
            INTERLEAVING_FACTOR => 4,
            N_SHD               => 128,
            DEBUG               => 0
        )
        port map (
            asi_hit_type2_0_channel       => x"0",
            asi_hit_type2_0_startofpacket => lane_sop(0),
            asi_hit_type2_0_endofpacket   => lane_eop(0),
            asi_hit_type2_0_data          => lane_data(0),
            asi_hit_type2_0_valid         => lane_valid(0),
            asi_hit_type2_0_ready         => lane_ready(0),
            asi_hit_type2_0_error         => '0',

            asi_hit_type2_1_channel       => x"1",
            asi_hit_type2_1_startofpacket => lane_sop(1),
            asi_hit_type2_1_endofpacket   => lane_eop(1),
            asi_hit_type2_1_data          => lane_data(1),
            asi_hit_type2_1_valid         => lane_valid(1),
            asi_hit_type2_1_ready         => lane_ready(1),
            asi_hit_type2_1_error         => '0',

            asi_hit_type2_2_channel       => x"2",
            asi_hit_type2_2_startofpacket => lane_sop(2),
            asi_hit_type2_2_endofpacket   => lane_eop(2),
            asi_hit_type2_2_data          => lane_data(2),
            asi_hit_type2_2_valid         => lane_valid(2),
            asi_hit_type2_2_ready         => lane_ready(2),
            asi_hit_type2_2_error         => '0',

            asi_hit_type2_3_channel       => x"3",
            asi_hit_type2_3_startofpacket => lane_sop(3),
            asi_hit_type2_3_endofpacket   => lane_eop(3),
            asi_hit_type2_3_data          => lane_data(3),
            asi_hit_type2_3_valid         => lane_valid(3),
            asi_hit_type2_3_ready         => lane_ready(3),
            asi_hit_type2_3_error         => '0',

            aso_hit_type3_startofpacket   => out_sop,
            aso_hit_type3_endofpacket     => out_eop,
            aso_hit_type3_data            => out_data,
            aso_hit_type3_valid           => out_valid,
            aso_hit_type3_ready           => out_ready,

            asi_ctrl_datapath_data        => ctrl_d_data,
            asi_ctrl_datapath_valid       => ctrl_d_valid,
            asi_ctrl_datapath_ready       => ctrl_d_ready,
            asi_ctrl_xcvr_data            => ctrl_x_data,
            asi_ctrl_xcvr_valid           => ctrl_x_valid,
            asi_ctrl_xcvr_ready           => ctrl_x_ready,

            avs_csr_readdata              => csr_readdata,
            avs_csr_read                  => csr_read,
            avs_csr_address               => csr_address,
            avs_csr_waitrequest           => csr_waitrequest,
            avs_csr_write                 => csr_write,
            avs_csr_writedata             => csr_writedata,

            aso_debug_ts_data             => debug_ts_data,
            aso_debug_ts_valid            => debug_ts_valid,
            aso_debug_burst_valid         => debug_burst_valid,
            aso_debug_burst_data          => debug_burst_data,
            aso_ts_delta_valid            => ts_delta_valid,
            aso_ts_delta_data             => ts_delta_data,
            aso_debug_filllevel_valid     => debug_filllevel_valid,
            aso_debug_filllevel_data      => debug_filllevel_data,
            aso_debug_loss8fill_valid     => debug_loss8fill_valid,
            aso_debug_loss8fill_data      => debug_loss8fill_data,
            aso_debug_delay8loss_valid    => debug_delay8loss_valid,
            aso_debug_delay8loss_data     => debug_delay8loss_data,

            i_clk_xcvr                    => clk_xcvr,
            i_clk_datapath                => clk_data,
            i_rst_xcvr                    => rst_xcvr,
            i_rst_datapath                => rst_data
        );

    stim : process
        procedure send_ctrl(cmd : std_logic_vector(8 downto 0)) is
        begin
            ctrl_d_data  <= cmd;
            ctrl_x_data  <= cmd;
            ctrl_d_valid <= '1';
            ctrl_x_valid <= '1';
            wait until rising_edge(clk_data);
            ctrl_d_valid <= '0';
            ctrl_x_valid <= '0';
            wait until rising_edge(clk_data);
        end procedure;
    begin
        wait for 80 ns;
        rst_xcvr <= '0';
        rst_data <= '0';
        wait until rising_edge(clk_data);

        send_ctrl("000000010"); -- RUN_PREPARE
        for i in 0 to 7 loop
            wait until rising_edge(clk_data);
        end loop;
        send_ctrl("000000100"); -- SYNC
        for i in 0 to 7 loop
            wait until rising_edge(clk_data);
        end loop;
        send_ctrl("000001000"); -- RUNNING
        for i in 0 to 15 loop
            wait until rising_edge(clk_data);
        end loop;

        for ts_base in 0 to 63 loop
            wait until rising_edge(clk_data);
            for lane in 0 to 3 loop
                lane_data(lane)  <= make_subheader(ts_base * 4 + lane);
                lane_sop(lane)   <= '1';
                lane_eop(lane)   <= '1';
                lane_valid(lane) <= '1';
            end loop;
        end loop;

        wait until rising_edge(clk_data);
        lane_valid <= (others => '0');
        lane_sop   <= (others => '0');
        lane_eop   <= (others => '0');
        lane_data  <= (others => (others => '0'));

        for i in 0 to 1000 loop
            wait until rising_edge(clk_data);
        end loop;

        send_ctrl("000010000"); -- TERMINATING: drain the second partial-in-RUNNING frame.

        for i in 0 to 2000 loop
            wait until rising_edge(clk_data);
            if done = '1' then
                report "TB PASS: two 128-subheader frames observed with packet and timestamp continuity";
                stop;
            end if;
        end loop;

        assert false report "timeout waiting for two completed frames" severity failure;
        stop;
    end process;

    monitor : process (clk_xcvr)
        variable in_frame_v          : boolean := false;
        variable frame_idx_v         : natural := 0;
        variable word_idx_v          : natural := 0;
        variable declared_subh_v     : natural := 0;
        variable declared_hits_v     : natural := 0;
        variable seen_subh_v         : natural := 0;
        variable seen_hits_v         : natural := 0;
        variable first_subh_valid_v  : boolean := false;
        variable first_subh_ts_v     : natural := 0;
        variable last_subh_ts_v      : natural := 0;
        variable packet_count_v      : natural := 0;
        variable last_packet_count_v : natural := 0;
        variable last_page_base_v    : natural := 0;
        variable have_last_frame_v   : boolean := false;
        variable header_hi_v         : std_logic_vector(31 downto 0) := (others => '0');
        variable header_lo_v         : std_logic_vector(31 downto 0) := (others => '0');
        variable frame_ts_v          : unsigned(47 downto 0) := (others => '0');
        variable last_frame_ts_v     : unsigned(47 downto 0) := (others => '0');
        variable subh_ts_v           : natural := 0;
        variable expected_ts_v       : natural := 0;
        variable zero_nibble_v       : std_logic_vector(3 downto 0) := (others => '0');
    begin
        if rising_edge(clk_xcvr) then
            if out_valid = '1' and out_ready = '1' then
                report "FRAME_WORD frame=" & integer'image(frame_idx_v) &
                       " idx=" & integer'image(word_idx_v) &
                       " sop=" & std_logic'image(out_sop) &
                       " eop=" & std_logic'image(out_eop) &
                       " data=0x" & to_hstring(out_data);

                if out_sop = '1' then
                    assert not in_frame_v report "new SOP before previous frame trailer" severity failure;
                    in_frame_v         := true;
                    word_idx_v         := 0;
                    declared_subh_v    := 0;
                    declared_hits_v    := 0;
                    seen_subh_v        := 0;
                    seen_hits_v        := 0;
                    first_subh_valid_v := false;
                end if;

                assert in_frame_v report "accepted output beat outside a Mu3e frame" severity failure;

                case word_idx_v is
                    when 0 =>
                        assert out_sop = '1' report "frame word 0 missing SOP" severity failure;
                        assert out_data(35 downto 32) = "0001" and out_data(7 downto 0) = x"BC"
                            report "frame word 0 is not K28.5 preamble" severity failure;
                    when 1 =>
                        assert out_data(35 downto 32) = "0000" report "header timestamp high has datak set" severity failure;
                        header_hi_v := out_data(31 downto 0);
                    when 2 =>
                        assert out_data(35 downto 32) = "0000" report "header timestamp low/count has datak set" severity failure;
                        header_lo_v    := out_data(31 downto 0);
                        packet_count_v := to_integer(unsigned(out_data(15 downto 0)));
                    when 3 =>
                        assert out_data(35 downto 32) = "0000" report "declared-count word has datak set" severity failure;
                        declared_subh_v := to_integer(unsigned(out_data(30 downto 16)));
                        declared_hits_v := to_integer(unsigned(out_data(15 downto 0)));
                        assert declared_subh_v = EXPECTED_SUBH_CONST
                            report "declared_subheaders mismatch: got " & integer'image(declared_subh_v)
                            severity failure;
                        assert declared_hits_v = 0
                            report "declared_hits mismatch: got " & integer'image(declared_hits_v)
                            severity failure;
                    when 4 =>
                        assert out_data(35 downto 32) = "0000" report "debug TTL word has datak set" severity failure;
                    when others =>
                        if out_eop = '1' then
                            assert out_data(35 downto 32) = "0001" and out_data(7 downto 0) = x"9C"
                                report "trailer is not K28.4" severity failure;
                            assert word_idx_v + 1 = EXPECTED_FRAME_WORDS_CONST
                                report "frame length mismatch: got " & integer'image(word_idx_v + 1) &
                                       " expected " & integer'image(EXPECTED_FRAME_WORDS_CONST)
                                severity failure;
                            assert seen_subh_v = EXPECTED_SUBH_CONST
                                report "seen_subheaders mismatch: got " & integer'image(seen_subh_v)
                                severity failure;
                            assert seen_hits_v = 0
                                report "unexpected hit words seen: " & integer'image(seen_hits_v)
                                severity failure;
                            assert first_subh_valid_v report "frame closed without subheaders" severity failure;
                            assert first_subh_ts_v = (frame_idx_v * EXPECTED_SUBH_CONST) mod 256
                                report "frame page base mismatch: got 0x" &
                                       to_hstring(std_logic_vector(to_unsigned(first_subh_ts_v, 8)))
                                severity failure;

                            frame_ts_v := unsigned(std_logic_vector'(
                                header_hi_v &
                                header_lo_v(31 downto 28) &
                                std_logic_vector(to_unsigned(first_subh_ts_v, 8)) &
                                zero_nibble_v));

                            if have_last_frame_v then
                                assert packet_count_v = (last_packet_count_v + 1) mod 65536
                                    report "packet_count not consecutive" severity failure;
                                assert first_subh_ts_v = (last_page_base_v + EXPECTED_SUBH_CONST) mod 256
                                    report "page base not consecutive" severity failure;
                                assert frame_ts_v - last_frame_ts_v = EXPECTED_FRAME_TICKS_CONST
                                    report "frame_start_ts delta mismatch: got 0x" &
                                           to_hstring(std_logic_vector(frame_ts_v - last_frame_ts_v))
                                    severity failure;
                            end if;

                            report "FRAME_SUMMARY frame=" & integer'image(frame_idx_v) &
                                   " words=" & integer'image(word_idx_v + 1) &
                                   " packet_count=0x" &
                                   to_hstring(std_logic_vector(to_unsigned(packet_count_v, 16))) &
                                   " first_subheader=0x" &
                                   to_hstring(std_logic_vector(to_unsigned(first_subh_ts_v, 8))) &
                                   " frame_start_ts=0x" & to_hstring(std_logic_vector(frame_ts_v));

                            last_packet_count_v := packet_count_v;
                            last_page_base_v    := first_subh_ts_v;
                            last_frame_ts_v     := frame_ts_v;
                            have_last_frame_v   := true;
                            in_frame_v          := false;
                            frame_idx_v         := frame_idx_v + 1;
                            word_idx_v          := 0;
                            if frame_idx_v = 2 then
                                done <= '1';
                            end if;
                        elsif out_data(35 downto 32) = "0001" and out_data(7 downto 0) = x"F7" then
                            subh_ts_v := to_integer(unsigned(out_data(31 downto 24)));
                            if first_subh_valid_v then
                                expected_ts_v := (last_subh_ts_v + 1) mod 256;
                                assert subh_ts_v = expected_ts_v
                                    report "subheader timestamp not consecutive: got 0x" &
                                           to_hstring(std_logic_vector(to_unsigned(subh_ts_v, 8))) &
                                           " expected 0x" &
                                           to_hstring(std_logic_vector(to_unsigned(expected_ts_v, 8)))
                                    severity failure;
                            else
                                first_subh_valid_v := true;
                                first_subh_ts_v    := subh_ts_v;
                            end if;
                            assert to_integer(unsigned(out_data(15 downto 8))) = 0
                                report "zero-hit stimulus produced nonzero subheader hit declaration"
                                severity failure;
                            last_subh_ts_v := subh_ts_v;
                            seen_subh_v    := seen_subh_v + 1;
                        else
                            seen_hits_v := seen_hits_v + 1;
                            assert false report "unexpected hit/data word in zero-hit frame" severity failure;
                        end if;
                end case;

                if out_eop /= '1' then
                    word_idx_v := word_idx_v + 1;
                end if;
            end if;
        end if;
    end process;

end architecture sim;
