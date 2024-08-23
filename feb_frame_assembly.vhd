-- File name: feb_frame_assembly.vhd 
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--		Date: Aug 6, 2024
-- =========
-- Description:	[Front-end Board Frame Assembly] 
--		This IP is generates the Mu3e standard data frame given input of sub-frames.
--
--		Note:
--			It includes input fifo for buffering input data stream from the stack cache ip.
--			It only de-assert ready when input fifo is full, in that case, the ring-buffer-cam ip 
--			needs to freeze the poping action until ready is asserted again. 
--			Reading at 1*156.25 MHz, which is higher than 1*125 MHz of the MuTRiG. So, overall it will never overflow.
--			But, in burst case (>256 time cluster of hits within sub-frame), this could result in a cam overwrite or 
--			input fifo overflow. (if observed, reduce stack-cache time interleaving factor or increase the cam depth and
--			increase the input fifo depth)
--		
--		Work flow:
--			Pack sub-frames in order to form a complete frame.
--			Issue upload_req to win the arbitration against slow control packet. 
--			

-- ================ synthsizer configuration =================== 		
-- altera vhdl_input_version vhdl_2008
-- ============================================================= 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.log2;
use IEEE.math_real.ceil;


entity feb_frame_assembly is
generic (
	INTERLEAVING_FACTOR				: natural := 4; -- set the same as upstream stack-cache 
	DEBUG							: natural := 1
);
port (
	-- avst from the stack-cache 
	asi_hit_type2_0_channel			: in  std_logic_vector(3 downto 0); -- max_channel=15
	asi_hit_type2_0_startofpacket	: in  std_logic; -- sop at each subheader
	asi_hit_type2_0_endofpacket		: in  std_logic; -- eop at last hit in this subheader. if no hit, eop at subheader.
	asi_hit_type2_0_data			: in  std_logic_vector(35 downto 0); -- [35:32] byte_is_k: "0001"=sub-header. "0000"=hit.
	-- two cases for [31:0]
	-- 1) sub-header: [31:24]=ts[11:4], [23:16]=TBD, [15:8]=hit_cnt[7:0], [7:0]=K23.7
	-- 2) hit: [31:0]=specbook MuTRiG hit format
	asi_hit_type2_0_valid			: in  std_logic;
	asi_hit_type2_0_ready			: out std_logic;
	
	asi_hit_type2_1_channel			: in  std_logic_vector(3 downto 0); -- max_channel=15
	asi_hit_type2_1_startofpacket	: in  std_logic; -- sop at each subheader
	asi_hit_type2_1_endofpacket		: in  std_logic; -- eop at last hit in this subheader. if no hit, eop at subheader.
	asi_hit_type2_1_data			: in  std_logic_vector(35 downto 0); -- [35:32] byte_is_k: "0001"=sub-header. "0000"=hit.
	asi_hit_type2_1_valid			: in  std_logic;
	asi_hit_type2_1_ready			: out std_logic;
	
	asi_hit_type2_2_channel			: in  std_logic_vector(3 downto 0); -- max_channel=15
	asi_hit_type2_2_startofpacket	: in  std_logic; -- sop at each subheader
	asi_hit_type2_2_endofpacket		: in  std_logic; -- eop at last hit in this subheader. if no hit, eop at subheader.
	asi_hit_type2_2_data			: in  std_logic_vector(35 downto 0); -- [35:32] byte_is_k: "0001"=sub-header. "0000"=hit.
	asi_hit_type2_2_valid			: in  std_logic;
	asi_hit_type2_2_ready			: out std_logic;
	
	asi_hit_type2_3_channel			: in  std_logic_vector(3 downto 0); -- max_channel=15
	asi_hit_type2_3_startofpacket	: in  std_logic; -- sop at each subheader
	asi_hit_type2_3_endofpacket		: in  std_logic; -- eop at last hit in this subheader. if no hit, eop at subheader.
	asi_hit_type2_3_data			: in  std_logic_vector(35 downto 0); -- [35:32] byte_is_k: "0001"=sub-header. "0000"=hit.
	asi_hit_type2_3_valid			: in  std_logic;
	asi_hit_type2_3_ready			: out std_logic;


	
	-- clock and reset interface 
	i_clk_xcvr						: std_logic; -- xclk
	i_clk_datapath					: std_logic; -- dclk
	i_rst_xcvr						: std_logic;
	i_rst_datapath					: std_logic
);
end entity feb_frame_assembly;


architecture rtl of feb_frame_assembly is 
	-- ------------------------------------
	-- globle constant
	-- ------------------------------------
	-- universal 8b10b
	constant K285					: std_logic_vector(7 downto 0) := "10111100"; -- 16#BC#
	constant K284					: std_logic_vector(7 downto 0) := "10011100"; -- 16#9C#
	constant K237					: std_logic_vector(7 downto 0) := "11110111"; -- 16#F7#
	-- global
	
	
	-- ------------------------------------
	-- input_lane_mapping
	-- ------------------------------------
	-- types
	type avst_input_t is record
		channel			: std_logic_vector(asi_hit_type2_0_channel'high downto 0);
		startofpacket	: std_logic;
		endofpacket		: std_logic;
		data			: std_logic_vector(asi_hit_type2_0_data'high downto 0);
		valid			: std_logic;
		ready			: std_logic;
	end record;
	type avst_inputs_t 				is array (0 to INTERLEAVING_FACTOR-1) of avst_input_t;
	
	-- signals
	signal avst_inputs				: avst_inputs_t;
	
	
	-- ---------------------------
	-- sub_frame_fifo
	-- ---------------------------
	-- constants
	constant SUB_FIFO_DATA_WIDTH			: natural := 40;
	constant SUB_FIFO_USEDW_WIDTH			: natural := 9; -- used one more bit for it
	constant SUB_FIFO_DEPTH					: natural := 256;
	constant SUB_FIFO_SOP_LOC				: natural := 37;
	constant SUB_FIFO_EOP_LOC				: natural := 36;
	
	-- types
	type sub_fifo_t is record
		wrreq		: std_logic;
		data		: std_logic_vector(SUB_FIFO_DATA_WIDTH-1 downto 0);
		wrempty		: std_logic;
		wrfull		: std_logic;
		wrusedw		: std_logic_vector(SUB_FIFO_USEDW_WIDTH-1 downto 0);
		rdreq		: std_logic;
		q			: std_logic_vector(SUB_FIFO_DATA_WIDTH-1 downto 0);
		rdempty		: std_logic;
		rdfull		: std_logic;
		rdusedw		: std_logic_vector(SUB_FIFO_USEDW_WIDTH-1 downto 0);
	end record;
	type sub_fifos_t				is array (0 to INTERLEAVING_FACTOR-1) of sub_fifo_t;
	
	-- signals
	signal sub_fifos				: sub_fifos_t;
	
	-- declaration
	component alt_dcfifo_w40d256
	PORT
	(
		data		: IN STD_LOGIC_VECTOR (SUB_FIFO_DATA_WIDTH-1 DOWNTO 0);
		rdclk		: IN STD_LOGIC ;
		rdreq		: IN STD_LOGIC ;
		wrclk		: IN STD_LOGIC ;
		wrreq		: IN STD_LOGIC ;
		q			: OUT STD_LOGIC_VECTOR (SUB_FIFO_DATA_WIDTH-1 DOWNTO 0);
		rdempty		: OUT STD_LOGIC ;
		rdfull		: OUT STD_LOGIC ;
		rdusedw		: OUT STD_LOGIC_VECTOR (SUB_FIFO_USEDW_WIDTH-1 DOWNTO 0);
		wrempty		: OUT STD_LOGIC ;
		wrfull		: OUT STD_LOGIC ;
		wrusedw		: OUT STD_LOGIC_VECTOR (SUB_FIFO_USEDW_WIDTH-1 DOWNTO 0)
	);
	end component;

	
	-- ------------------------------------
	-- lane_scheduler
	-- ------------------------------------
	constant LANE_INDEX_WIDTH					: natural := integer(ceil(log2(real(INTERLEAVING_FACTOR)))); -- 2
	constant SUBHEADER_TIMESTAMP_WIDTH			: natural := 8;
	signal scheduler_selected_timestamp			: unsigned(SUBHEADER_TIMESTAMP_WIDTH-1 downto 0);
	signal scheduler_selected_lane_binary		: unsigned(LANE_INDEX_WIDTH-1 downto 0);
	signal scheduler_out_valid					: std_logic;
	signal scheduler_overflow_flags				: std_logic_vector(INTERLEAVING_FACTOR-1 downto 0);
	signal scheduler_timestamp_valid			: std_logic_vector(INTERLEAVING_FACTOR-1 downto 0);
	signal scheduler_selected_lane_onehot		: std_logic_vector(INTERLEAVING_FACTOR-1 downto 0);
	
	
	-- -------------------------------------
	-- sub_fifo_write_logic
	-- -------------------------------------
	-- types
	type subfifo_trans_status_single_t 		is (IDLE, TRANSMISSION, MASKED, RESET);
	type subfifo_trans_status_t				is array (0 to INTERLEAVING_FACTOR-1) of subfifo_trans_status_single_t;
	type subheader_hit_cnt_t				is array (0 to INTERLEAVING_FACTOR-1) of std_logic_vector(7 downto 0);
	type subfifo_counter_t					is array (0 to INTERLEAVING_FACTOR-1) of unsigned(47 downto 0);
	type debug_msg_t is record
		declared_hit_cnt			: subfifo_counter_t;
		actual_hit_cnt				: subfifo_counter_t;
		missing_hit_cnt				: subfifo_counter_t;
	end record;
	type word_is_subheader_t				is array (0 to INTERLEAVING_FACTOR-1) of std_logic;
	type word_is_subtrailer_t				is array (0 to INTERLEAVING_FACTOR-1) of std_logic;
	
	-- signals
	signal subfifo_trans_status				: subfifo_trans_status_t;
	signal subheader_hit_cnt				: subheader_hit_cnt_t;
	signal subheader_hit_cnt_comb			: subheader_hit_cnt_t;
	signal debug_msg						: debug_msg_t;
	signal word_is_subheader				: word_is_subheader_t;
	signal word_is_subtrailer				: word_is_subtrailer_t;
	
	
	-- ---------------------------
	-- frame_delimiter_marker
	-- ---------------------------
	-- types
	type showahead_timestamp_t				is array (0 to INTERLEAVING_FACTOR-1) of unsigned(7 downto 0);
	type pipe_de2wr_t is record
		eop_all_valid			: std_logic;
		eop_all					: std_logic;
		eop_all_ack				: std_logic;
	end record;
	
	-- signals
	signal showahead_timestamp				: showahead_timestamp_t;
	signal showahead_timestamp_last			: showahead_timestamp_t;
	signal showahead_timestamp_d1			: showahead_timestamp_t;
	signal pipe_de2wr						: pipe_de2wr_t;
	signal xcvr_word_is_subheader			: word_is_subheader_t; -- same helper but in different clocks
	signal xcvr_word_is_subtrailer			: word_is_subtrailer_t;
	
	
	-- --------------------------------------------
	-- main_fifo_write_logic (storing Mu3e data frame)
	-- --------------------------------------------
	-- constants
	constant MAIN_FIFO_DATA_WIDTH			: natural := 40;
	constant MAIN_FIFO_USEDW_WIDTH			: natural := 11; -- do not use 1 more bit
	constant MAIN_FIFO_DEPTH				: natural := 2048;
	
	-- declaration
	component alt_scfifo_w40d2k
	PORT
	(
		clock		: IN STD_LOGIC ;
		data		: IN STD_LOGIC_VECTOR (MAIN_FIFO_DATA_WIDTH-1 DOWNTO 0);
		rdreq		: IN STD_LOGIC ;
		sclr		: IN STD_LOGIC ;
		wrreq		: IN STD_LOGIC ;
		empty		: OUT STD_LOGIC ;
		full		: OUT STD_LOGIC ;
		q			: OUT STD_LOGIC_VECTOR (MAIN_FIFO_DATA_WIDTH-1 DOWNTO 0);
		usedw		: OUT STD_LOGIC_VECTOR (MAIN_FIFO_USEDW_WIDTH-1 DOWNTO 0)
	);
	end component;
	
	-- types
	type main_fifo_wr_status_t 		is (IDLE, START_OF_FRAME, TRANSMISSION, LOOK_AROUND, END_OF_FRAME, RESET);
	type csr_t is record
		feb_type			: std_logic_vector(5 downto 0);
		feb_id				: std_logic_vector(15 downto 0);
	end record;
	
	-- signal 
	signal main_fifo_rdreq				: std_logic;
	signal main_fifo_wrreq				: std_logic;
	signal main_fifo_din				: std_logic_vector(MAIN_FIFO_DATA_WIDTH-1 downto 0);
	signal main_fifo_dout				: std_logic_vector(MAIN_FIFO_DATA_WIDTH-1 downto 0);
	signal main_fifo_empty				: std_logic;
	signal main_fifo_full				: std_logic;
	signal main_fifo_sclr				: std_logic;
	signal main_fifo_usedw				: std_logic_vector(MAIN_FIFO_USEDW_WIDTH-1 downto 0);
	signal sof_counter					: unsigned(2 downto 0);
	signal main_fifo_decision			: std_logic_vector(LANE_INDEX_WIDTH-1 downto 0);
	signal main_fifo_wr_status			: main_fifo_wr_status_t;
	signal sub_dout						: std_logic_vector(MAIN_FIFO_DATA_WIDTH-1 downto 0);
	signal sub_empty					: std_logic;
	signal sub_rdreq					: std_logic;
	signal sub_eop_is_seen				: std_logic;
	signal insert_trailer_done			: std_logic;
	signal main_fifo_wr_data			: std_logic_vector(MAIN_FIFO_DATA_WIDTH-1 downto 0);
	signal main_fifo_wr_valid			: std_logic;
	signal csr							: csr_t;
	
	
	-- ----------------------------------------------
	-- transmission_timestamp_poster 
	-- ----------------------------------------------
	signal frame_cnt						: unsigned(35 downto 0);
	signal gts_8n_in_transmission			: std_logic_vector(47 downto 0);
	
begin

	-- ------------------------------------
	-- input_lane_mapping
	-- ------------------------------------
	proc_map_avst_input : process (all)
	begin
		-- ** input **
		-- channel
		avst_inputs(0).channel				<= asi_hit_type2_0_channel;
		avst_inputs(1).channel				<= asi_hit_type2_1_channel;
		avst_inputs(2).channel				<= asi_hit_type2_2_channel;
		avst_inputs(3).channel				<= asi_hit_type2_3_channel;
		-- sop
		avst_inputs(0).startofpacket		<= asi_hit_type2_0_startofpacket;
		avst_inputs(1).startofpacket		<= asi_hit_type2_1_startofpacket;
		avst_inputs(2).startofpacket		<= asi_hit_type2_2_startofpacket;
		avst_inputs(3).startofpacket		<= asi_hit_type2_3_startofpacket;
		-- eop
		avst_inputs(0).endofpacket			<= asi_hit_type2_0_endofpacket;
		avst_inputs(1).endofpacket			<= asi_hit_type2_1_endofpacket;
		avst_inputs(2).endofpacket			<= asi_hit_type2_2_endofpacket;
		avst_inputs(3).endofpacket			<= asi_hit_type2_3_endofpacket;
		-- data
		avst_inputs(0).data					<= asi_hit_type2_0_data;
		avst_inputs(1).data					<= asi_hit_type2_1_data;
		avst_inputs(2).data					<= asi_hit_type2_2_data;
		avst_inputs(3).data					<= asi_hit_type2_3_data;
		-- valid
		avst_inputs(0).valid				<= asi_hit_type2_0_valid;
		avst_inputs(1).valid				<= asi_hit_type2_1_valid;
		avst_inputs(2).valid				<= asi_hit_type2_2_valid;
		avst_inputs(3).valid				<= asi_hit_type2_3_valid;

		-- ** output **
		-- ready
		asi_hit_type2_0_ready				<= avst_inputs(0).ready;
		asi_hit_type2_1_ready				<= avst_inputs(1).ready;
		asi_hit_type2_2_ready				<= avst_inputs(2).ready;
		asi_hit_type2_3_ready				<= avst_inputs(3).ready;
	end process;
	
	
	-- ---------------------------
	-- sub_frame_fifo
	-- ---------------------------
	-- ** instantiation **
	gen_sub_fifos : for i in 0 to INTERLEAVING_FACTOR-1 generate 
		-- used one more bit for the usedw
		sub_frame_fifo : alt_dcfifo_w40d256 PORT MAP (
			-- write side (datapath clock)
			wrclk	 => i_clk_datapath,
			wrreq	 => sub_fifos(i).wrreq,
			data	 => sub_fifos(i).data,
			wrempty	 => sub_fifos(i).wrempty,
			wrfull	 => sub_fifos(i).wrfull,
			wrusedw	 => sub_fifos(i).wrusedw,
			-- read side (xcvr clock)
			rdclk	 => i_clk_xcvr,
			rdreq	 => sub_fifos(i).rdreq,
			q	 	 => sub_fifos(i).q,
			rdempty	 => sub_fifos(i).rdempty,
			rdfull	 => sub_fifos(i).rdfull,
			rdusedw	 => sub_fifos(i).rdusedw
		);
		-- io mapping (expand 2d array to 1d list)
		--infifo_rd_engine_subheader_list(i)		<= sub_fifos(i).q(asi_hit_type2_0_data'high downto 0);
		--infifo_rd_engine_subheader_ts_list(i)	<= infifo_rd_engine_subheader_list(i)(31 downto 24); -- ts (11:4)
	end generate gen_sub_fifos;
	
	
	-- ------------------------------------
	-- lane_scheduler (for lane selection)
	-- ------------------------------------
	proc_lane_scheduler_comb : process (all)
		-- constants
		constant TIMESTAMP_WIDTH		: natural := 8;
		constant N_LANE					: natural := INTERLEAVING_FACTOR; -- 4
		-- types
		type timestamp_t				is array (0 to N_LANE-1) of unsigned(TIMESTAMP_WIDTH downto 0); -- + 1 bit
		type comp_tmp_t					is array (0 to N_LANE-2) of unsigned(TIMESTAMP_WIDTH downto 0); -- + 1 bit
		type index_tmp_t				is array (0 to N_LANE-2) of unsigned(LANE_INDEX_WIDTH-1 downto 0); 
		-- signals
		variable timestamp				: timestamp_t;
		variable comp_tmp				: comp_tmp_t;
		variable index_tmp				: index_tmp_t;
	begin
		-- input timestamp
		for i in 0 to N_LANE-1 loop
			timestamp(i)		:= scheduler_overflow_flags(i) & unsigned(sub_fifos(i).q(31 downto 24)); -- the overflow lane will be always larger
		end loop;
		
		-- algorithm: finding the smallest element of an array 
		-- input comparator (input stage)
		if (timestamp(0) <= timestamp(1)) then 
			comp_tmp(0)		:= timestamp(0);
			index_tmp(0)	:= to_unsigned(0,LANE_INDEX_WIDTH);
		else
			comp_tmp(0)		:= timestamp(1);
			index_tmp(0)	:= to_unsigned(1,LANE_INDEX_WIDTH);
		end if;
		-- cascade comparator
		for i in 0 to N_LANE-3 loop -- preferr lane lsb
			if (comp_tmp(i) <= timestamp(i+2)) then 
				comp_tmp(i+1)		:= comp_tmp(i);
				index_tmp(i+1)		:= index_tmp(i);
			else
				comp_tmp(i+1)		:= timestamp(i+2);
				index_tmp(i+1)		:= to_unsigned(i+2,LANE_INDEX_WIDTH);
			end if;
		end loop;
		-- output comparator (last stage)
		scheduler_selected_timestamp		<= comp_tmp(N_LANE-2);
		scheduler_selected_lane_binary		<= index_tmp(N_LANE-2);
		for i in 0 to N_LANE-1 loop
			if (i = to_integer(unsigned(index_tmp(N_LANE-2)))) then 
				scheduler_selected_lane_onehot(i)	<= '1';
			else 
				scheduler_selected_lane_onehot(i)	<= '0';
			end if;
		end loop;

		-- output valid
		if (scheduler_timestamp_valid = (N_LANE-1 downto 0 => '1')) then -- all lanes are valid, then output is valid
			scheduler_out_valid		<= '1';
		else 
			scheduler_out_valid		<= '0';
		end if;
	
	end process;
	
	
	-- ----------------------------------------
	-- sub_fifo_write_logic [datapath clock]
	-- ----------------------------------------
	
	gen_sub_fifo_write_logic : for i in 0 to INTERLEAVING_FACTOR-1 generate 
		-- ** sequential **
		proc_sub_fifo_write : process (i_clk_datapath, i_rst_datapath) 
		begin
			if (rising_edge(i_clk_datapath)) then 
				if (i_rst_datapath = '1') then
					subfifo_trans_status(i)		<= RESET;
					subheader_hit_cnt(i)		<= (others => '0');
				else 
					case subfifo_trans_status(i) is 
						when IDLE =>
							if (word_is_subheader(i) = '1') then
								if (sub_fifos(i).wrfull = '0') then -- subheader gets in the fifo
									debug_msg.declared_hit_cnt(i)	<= debug_msg.declared_hit_cnt(i) + unsigned(subheader_hit_cnt_comb(i)); -- record the declared hit count
									subheader_hit_cnt(i)			<= subheader_hit_cnt_comb(i); -- record for this subframe period
									if (word_is_subtrailer(i) = '1') then -- not hit in this subframe
										subfifo_trans_status(i)		<= IDLE; -- go back to idle
										subheader_hit_cnt(i)		<= (others => '0');
									else 
										subfifo_trans_status(i)		<= TRANSMISSION; -- go to collect hits
									end if;
								else -- subheader not in the fifo (because it is currently full) mask the subsequent hits until the next subheader
									subfifo_trans_status(i)		<= MASKED;
								end if;
							end if;
						when TRANSMISSION =>
							if (sub_fifos(i).wrreq = '1') then -- hits gets write to fifo
								debug_msg.actual_hit_cnt(i)		<= debug_msg.actual_hit_cnt(i) + 1; -- incr actual hit counter
							end if;
							if (word_is_subtrailer(i) = '1') then -- go back to idle when eop of this subframe is seen
								subfifo_trans_status(i)		<= IDLE;
								subheader_hit_cnt(i)		<= (others => '0');
							end if;
						when MASKED =>
							if (avst_inputs(i).valid = '1') then -- attemps to write the subsequent hits, but they are masked by the fifo, as their subheader was ignored
								if (avst_inputs(i).endofpacket = '1') then -- go back to idle, end of subframe transaction
									subfifo_trans_status(i)		<= IDLE;
									subheader_hit_cnt(i)		<= (others => '0');
								end if;
								-- record what is missing
								debug_msg.missing_hit_cnt(i)	<= debug_msg.missing_hit_cnt(i) + 1;
							end if;
						when RESET =>
							subheader_hit_cnt(i)				<= (others => '0');
							debug_msg.declared_hit_cnt(i)		<= (others => '0');
							debug_msg.actual_hit_cnt(i)			<= (others => '0');
							debug_msg.missing_hit_cnt(i)		<= (others => '0');
						when others => 
					end case;
				end if;
			end if;
		end process;
		
		-- ** helpers **
		proc_word_is_subheader_subfifo_wr : process (all)
		begin
			word_is_subheader(i)		<= '0';
			subheader_hit_cnt_comb(i)	<= (others => '0');
			if (avst_inputs(i).valid = '1') then -- check with valid
				if (avst_inputs(i).startofpacket = '1') then
					word_is_subheader(i)		<= '1';
					subheader_hit_cnt_comb(i)	<= avst_inputs(i).data(15 downto 8); -- from 0 to 255, but it can actually be up to 512 ...
				end if;
			end if;
		end process;
		
		proc_word_is_subtrailer_subfifo_wr : process (all) -- unlike subheader contains info, the subtrail contains the last hit
		begin
			word_is_subtrailer(i)			<= '0';
			if (avst_inputs(i).valid = '1') then 
				if (avst_inputs(i).endofpacket = '1') then
					word_is_subtrailer(i)		<= '1';
				end if;
			end if;
		end process;
		
		-- ** combinational **
		proc_sub_fifo_write_comb : process (all)
		-- input direct drives the write port
		begin
			-- default
			sub_fifos(i).data(avst_inputs(i).data'high downto 0)		<= avst_inputs(i).data; -- connect data input directly to fifo (35 downto 0)
			sub_fifos(i).data(avst_inputs(i).data'high+1)				<= avst_inputs(i).endofpacket; -- bit 36
			sub_fifos(i).data(avst_inputs(i).data'high+2)				<= avst_inputs(i).startofpacket; -- bit 37
			sub_fifos(i).data(sub_fifos(i).data'high downto avst_inputs(i).data'high+3)	<= (others => '0'); -- bit 38-39 (free to allocate, TDB)
			-- assert backpressure to the ring-buffer-cam, ready latency is 0
			if (subfifo_trans_status(i) /= MASKED) then 
				if (avst_inputs(i).valid = '1') then -- write if input is valid. if full, the fifo itself will take care (ignoring them)
					sub_fifos(i).wrreq		<= '1';
				else
					sub_fifos(i).wrreq		<= '0';
				end if;
			else -- fifo is full or hits are masked
				
				-- if the subheader is in, hits can be accepted (if not full). if subheader is not in, subsequent hits are ignored for sure. 
				sub_fifos(i).wrreq		<= '0'; -- do not write
			end if;
			-- derive the ready for the upstream
			--if (sub_fifos(i).wrusedw > 
			avst_inputs(i).ready		<= '1';
				--avst_inputs(i).ready		<= '0'; -- upstream sense it and halt the change of data immediately, or the data is ignored. 
		end process;
		
	end generate gen_sub_fifo_write_logic;
	
	
	-- ---------------------------
	-- frame_delimiter_marker
	-- ---------------------------
	-- ** sequential **
	proc_frame_delimiter_marker : process (i_clk_xcvr, i_rst_xcvr) 
	begin
		if (rising_edge(i_clk_xcvr)) then 
			if (i_rst_xcvr = '1') then
			
			else 
				for i in 0 to INTERLEAVING_FACTOR-1 loop
					-- continuously latch the showahead subframe timestamp on the read side 
					if (xcvr_word_is_subheader(i) = '1') then -- check with valid already, sop is seen on the infifo read side
						-- latch the showahead ts of the lane
						showahead_timestamp(i)		<= unsigned(sub_fifos(i).q(31 downto 24)); 
						showahead_timestamp_last(i)	<= showahead_timestamp(i); -- remember the last value
						
					end if;
					showahead_timestamp_d1(i)		<= showahead_timestamp(i); -- delay line for derive valid
					if (scheduler_timestamp_valid = (INTERLEAVING_FACTOR-1 downto 0 => '1')) then
						pipe_de2wr.eop_all_valid		<= '1';
					else
						pipe_de2wr.eop_all_valid		<= '0';
					end if;
						
					-- alert overflow has happened
					if (scheduler_overflow_flags = (INTERLEAVING_FACTOR-1 downto 0 => '1')) then -- all lane overflowed, we unset the flags in each lane
						scheduler_overflow_flags(i)		<= '0';
					elsif (showahead_timestamp(i) < showahead_timestamp_last(i)) then -- the lane should always source new timestamp larger than old one, this abnormal means overflow
						scheduler_overflow_flags(i)		<= '1'; -- NOTE: overflow flags all is only valid for 1 cycle
					end if;
				end loop; 
				
				-- pipe with main fifo write logic
				if (scheduler_overflow_flags = (INTERLEAVING_FACTOR-1 downto 0 => '1')) then 
					pipe_de2wr.eop_all		<= '1'; -- inter-fsm communication pipe, set by overflow flags are set for all lanes, enough for it to set
				elsif (pipe_de2wr.eop_all_ack = '1') then
					pipe_de2wr.eop_all		<= '0'; -- unset as child ack it
				end if;
			end if;
		end if;
	end process;
	
	-- ** combinational **
	proc_frame_delimiter_marker_comb : process (all)
	begin
		-- if there is change, supply timestamp to the scheduler is not valid
		for i in 0 to INTERLEAVING_FACTOR-1 loop
			-- frame delimiter output valid signal
			if (showahead_timestamp(i) = showahead_timestamp_d1(i)) then 
				scheduler_timestamp_valid(i)		<= '1';
			else 
				scheduler_timestamp_valid(i)		<= '0';
			end if;
		end loop;
	end process;
	
	-- ** helpers **
	gen_helpers_xcvr : for i in 0 to INTERLEAVING_FACTOR-1 generate 
		proc_word_is_subheader_xcvr : process (all)
		begin
			xcvr_word_is_subheader(i)		<= '0';
			if (sub_fifos(i).rdempty = '0') then -- check with valid
				if (sub_fifos(i).q(SUB_FIFO_SOP_LOC) = '1') then 
					xcvr_word_is_subheader(i)		<= '1';
				end if;
			end if;
		end process;
	end generate gen_helpers_xcvr;
	
	
	-- --------------------------------------------
	-- main_fifo_write_logic (storing Mu3e data frame)
	-- --------------------------------------------
	-- ** instantiation **
	main_frame_fifo : alt_scfifo_w40d2k PORT MAP (
		-- clock
		clock	 => i_clk_xcvr,
		-- write side
		wrreq	 => main_fifo_wrreq,
		data	 => main_fifo_din,
		-- read side
		rdreq	 => main_fifo_rdreq,
		q	 	 => main_fifo_dout,
		-- control and status 
		empty	 => main_fifo_empty,
		full	 => main_fifo_full,
		sclr	 => main_fifo_sclr,
		usedw	 => main_fifo_usedw
	);
	
	-- ** sequential **
	proc_main_fifo_wr : process (i_clk_xcvr, i_rst_xcvr) 
	begin
		if (rising_edge(i_clk_xcvr)) then 
			if (i_rst_xcvr = '1') then
			
			else 
				-- default
				main_fifo_wr_data			<= (others => '0');
				case main_fifo_wr_status is
					when IDLE =>
						if (scheduler_out_valid = '1') then
							main_fifo_decision		<= std_logic_vector(scheduler_selected_lane_binary); -- latch the current selection
							main_fifo_wr_status		<= START_OF_FRAME;
						end if;
					when START_OF_FRAME => -- write some preamp and header before going into writing sub-frames
						if (main_fifo_full /= '1') then
							sof_counter		<= sof_counter + 1;
						end if;
						case to_integer(sof_counter) is 
							when 0 => -- preamble
								main_fifo_wr_data(35 downto 32)		<= "0001";
								main_fifo_wr_data(31 downto 26)		<= csr.feb_type;
								main_fifo_wr_data(23 downto 8)		<= csr.feb_id;
								main_fifo_wr_data(7 downto 0)		<= K284;
								main_fifo_wr_valid					<= '1';
							when 1 => -- data header 0
								main_fifo_wr_data					<= gts_8n_in_transmission(47 downto 16);
								main_fifo_wr_valid					<= '1';
							when 2 => -- data header 1
								main_fifo_wr_data(31 downto 16)		<= gts_8n_in_transmission(15 downto 0);
								main_fifo_wr_data(15 downto 0)		<= std_logic_vector(frame_cnt)(15 downto 0);
								main_fifo_wr_valid					<= '1';
							when 3 => -- debug header 0
								main_fifo_wr_valid					<= '1'; -- TODO: fill this when read out
							when 4 => -- debug header 1
								main_fifo_wr_valid					<= '1'; -- TODO: fill this when read out
								main_fifo_wr_status					<= TRANSMISSION;
								sof_counter							<= (others => '0');
							when others =>
						end case;
					when TRANSMISSION =>
						if (sub_eop_is_seen = '1') then
							main_fifo_wr_status		<= LOOK_AROUND; -- must go immediately 
						end if;
					when LOOK_AROUND =>
						if (pipe_de2wr.eop_all_valid = '1' and pipe_de2wr.eop_all = '1') then -- all eop of lanes are seen, finish this frame and ack the parent
							main_fifo_wr_status		<= END_OF_FRAME;
							pipe_de2wr.eop_all_ack	<= '1';
						elsif (pipe_de2wr.eop_all_valid = '1' and pipe_de2wr.eop_all = '0') then -- not all eop of lanes are seen, we can start to select another lane for another subframe
							main_fifo_wr_status		<= IDLE;
						end if; -- else wait
					when END_OF_FRAME =>
						if (pipe_de2wr.eop_all = '0') then   -- unset the pipe
							pipe_de2wr.eop_all_ack		<= '0';
							main_fifo_wr_status			<= RESET;
						end if;
						if (insert_trailer_done = '0') then
							insert_trailer_done		<= '1';
							main_fifo_wr_data(35 downto 32)		<= "0001";
							main_fifo_wr_data(7 downto 0)		<= K284;
							main_fifo_wr_valid		<= '1';
						else 
							main_fifo_wr_valid		<= '0';
						end if;
					when RESET =>
						main_fifo_wr_status			<= IDLE;
					when others =>
				end case;
			end if;
		end if;
	end process;
	
	-- ** combinational **
	proc_main_fifo_wr_comb : process (all)
	begin
		-- connect the main fifo write side with the main fifo write logic 
		-- default
		sub_dout				<= (others => '0');
		for i in 0 to INTERLEAVING_FACTOR-1 loop
			sub_fifos(i).rdreq		<= '0'; -- default
			if (main_fifo_wr_status = TRANSMISSION) then 
				if (to_integer(unsigned(main_fifo_decision)) = i) then -- if selected, connect this sub fifo to main fifo
					sub_fifos(i).rdreq		<= sub_rdreq;
					sub_dout				<= sub_fifos(i).q;
					sub_empty				<= sub_fifos(i).rdempty;
				end if;
			end if;
		end loop;
		
		if (main_fifo_wr_status = TRANSMISSION) then 
			main_fifo_din			<= sub_dout; -- direct wire up the out of sub fifo to in of main fifo
		elsif (main_fifo_wr_status = END_OF_FRAME or main_fifo_wr_status = START_OF_FRAME) then -- give control to the main fifo
			main_fifo_din			<= main_fifo_wr_data;
		else 
			main_fifo_din			<= (others => '0');
		end if;
			
		if (sub_empty = '0' and main_fifo_wr_status = TRANSMISSION) then -- write normally when sub fifo's dout is valid, in comb
			main_fifo_wrreq		<= '1';
			sub_rdreq			<= '1'; -- write to the main fifo, at the same time ack the read 
		elsif (main_fifo_wr_status = END_OF_FRAME or main_fifo_wr_status = START_OF_FRAME) then
			main_fifo_wrreq		<= 	main_fifo_wr_valid;
			sub_rdreq			<= '0';
		else 
			main_fifo_wrreq		<= '0';
			sub_rdreq			<= '0';
		end if;
		
		if (sub_empty = '0' and sub_dout(SUB_FIFO_EOP_LOC) = '1') then -- when eop is seen, alert main_fifo_wr_logic into finishing
			sub_eop_is_seen		<= '1';
		else
			sub_eop_is_seen		<= '0';
		end if;
	end process;
	
	
	-- ----------------------------------------------
	-- transmission_timestamp_poster 
	-- ----------------------------------------------
	-- ** sequential **
	proc_transmission_timestamp_poster : process (i_clk_xcvr, i_rst_xcvr) 
	begin
		if (rising_edge(i_clk_xcvr)) then 
			if (i_rst_xcvr = '1') then
				frame_cnt		<= (others => '0');
			else 
				if (main_fifo_wr_status = END_OF_FRAME and insert_trailer_done = '0') then -- the first cycle of frame trailer
					frame_cnt		<= frame_cnt + 1;
				end if;
			end if;
		end if;
	end process;
	
	-- ** combinational **
	proc_transmission_timestamp_poster_comb : process (all)
	begin
		gts_8n_in_transmission(11 downto 4)		<= (others => '0');
		gts_8n_in_transmission(47 downto 12)	<= std_logic_vector(frame_cnt);
	end process;




end architecture rtl;














