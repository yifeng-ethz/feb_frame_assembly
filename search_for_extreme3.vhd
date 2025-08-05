-- File name: search_for_extreme3.vhd 
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--		Date: Jul 4, 2025
-- =========
-- Description:	[Search For Extreme3] 
--      Debrief:
--		   Given the input array, find the maximum or minimum value of the array. 
--
--      Usage: 
--          Supply array to be search on <ingress> interface and retrieve the result on the <result> interface
--          New value at input will flush the output dangling result
--
-- ================ synthsizer configuration ===================	
-- altera vhdl_input_version vhdl_2008
-- ============================================================= 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.log2;
use IEEE.math_real.ceil;
use ieee.std_logic_misc.and_reduce;
use ieee.std_logic_misc.or_reduce;

entity search_for_extreme3 is 
generic (
    -- IP settings
    SEARCH_TARGET           : string := "MIN"; -- {MAX MIN}
    SEARCH_ARCH             : string := "LIN"; -- {LIN QUAD} LIN: linear talking search (time=O(N),space=O(N)); QUAD: pipeline binary search (time=O(log2(N)),space=O(2N))
    N_ELEMENT               : natural := 4; -- total number of elements 
    ELEMENT_SZ_BITS         : natural := 9; -- [bits] array is consists of equal size elements, the size of each element
    ARRAY_SZ_BITS           : natural := 36; -- [bits] total array size in bits
    ELEMENT_INDEX_BITS      : natural := 2

);
port(
    -- avst <ingress> : the input array to be searched on
    asi_ingress_data        : in  std_logic_vector(ARRAY_SZ_BITS-1 downto 0); -- pack of array, lsb and smallest array index in lower bits. ex: [array<3>[3 2 1 0] array<2>[3 2 1 0] array<1>[3 2 1 0] array<0>[3 2 1 0]]
    asi_ingress_valid       : in  std_logic; -- source should indicate whether the data is valid. it can happen that some lanes are been updated
    
    -- avst <result> : the output element find by the search
    aso_result_data         : out std_logic_vector(ELEMENT_SZ_BITS+ELEMENT_INDEX_BITS-1 downto 0); -- the result consists of [element_max/min element_index]
    aso_result_valid        : out std_logic; -- source indicate the availability of the search result
    
    -- clock <clk> : the clock interface of the whole IP
    i_clk                   : in  std_logic;
    -- reset <rst> : the reset interface of the whole IP
    i_rst                   : in  std_logic
);
end entity search_for_extreme3;

architecture rtl of search_for_extreme3 is 

    constant N_STAGES       : natural := integer(ceil(log2(real(N_ELEMENT)))); -- 4 elements will have 2 stages, 8 elements will have 3 stages, etc.
    type value_i_t is array (0 to 1) of std_logic_vector(ELEMENT_SZ_BITS-1 downto 0); -- the input value, two inputs for each node
    type index_i_t is array (0 to 1) of std_logic_vector(ELEMENT_INDEX_BITS-1 downto 0); -- the input index, two inputs for each node
    type node_t is record
        value_i     : value_i_t;
        index_i     : index_i_t; -- the input value and index, two inputs for each node
        value_o     : std_logic_vector(ELEMENT_SZ_BITS-1 downto 0); -- the output value, one output for each node
        index_o     : std_logic_vector(ELEMENT_INDEX_BITS-1 downto 0); -- the output index, one output for each node
    end record;
    type stage_t is array (0 to 2**N_STAGES-1) of node_t; -- the array of nodes at each stage, each stage has 2^N_STAGES nodes
    type tree_array_t is array (0 to N_STAGES-1) of stage_t; -- the array of nodes
    signal node : tree_array_t; -- the array of nodes, each node has two inputs and one output

    signal stage_valid : std_logic_vector(N_STAGES-1 downto 0); -- the valid signal for each stage, indicating whether the stage is valid or not

begin
    proc_tree_comparator : process (i_clk)
    begin
        if rising_edge(i_clk) then
            -- 1st stage
            stage_valid(0)              <= asi_ingress_valid;

            gen_stages: for i in 0 to N_STAGES-1 loop -- number of stages: from 0 to 1
                gen_nodes: for j in 0 to 2**(N_STAGES-i-1)-1 loop -- number of comparator at this stage: from 0 to 1 (i=0), from 0 to 0 (i=1)
                    if (node(i)(j).value_i(0) < node(i)(j).value_i(1)) then 
                        node(i)(j).value_o          <= node(i)(j).value_i(0);
                        node(i)(j).index_o          <= node(i)(j).index_i(0);
                    else
                        node(i)(j).value_o          <= node(i)(j).value_i(1);
                        node(i)(j).index_o          <= node(i)(j).index_i(1);
                    end if;
                end loop;
            end loop;

            gen_stage_flags : for i in 0 to N_STAGES-2 loop -- from 0 to 0
                stage_valid(i+1)        <= stage_valid(i);
            end loop;
        end if;
    end process;

    proc_tree_comparator_comb : process (all)
    begin
        gen_connection_1st : for j in 0 to 2**(N_STAGES-1)-1 loop -- number of comparator at first stage: from 0 to 1
            for k in 0 to 1 loop
                node(0)(j).value_i(k)            <= asi_ingress_data((2*j+k+1)*ELEMENT_SZ_BITS-1 downto (2*j+k)*ELEMENT_SZ_BITS);
                node(0)(j).index_i(k)            <= std_logic_vector(to_unsigned(2*j + k, ELEMENT_INDEX_BITS)); -- the index is the position of the element in the array, from 0 to N_ELEMENT-1
            end loop;
        end loop;

        gen_connection_mid : for i in 1 to N_STAGES-1 loop -- from 1 to 1
            for j in 0 to 2**(N_STAGES-i-1)-1 loop -- number of comparator with input, from 0 to 0
                node(i)(j).value_i(0)    <= node(i-1)(2*j).value_o;
                node(i)(j).index_i(0)    <= node(i-1)(2*j).index_o;
                node(i)(j).value_i(1)    <= node(i-1)(2*j+1).value_o;
                node(i)(j).index_i(1)    <= node(i-1)(2*j+1).index_o;
            end loop;
        end loop;

        -- last stage
        aso_result_data                 <= node(N_STAGES-1)(0).value_o & node(N_STAGES-1)(0).index_o;
        aso_result_valid                <= stage_valid(N_STAGES-1);
    end process;

end architecture;