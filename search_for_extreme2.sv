// High-Speed Pipelined Minimum Value Comparator
// Finds the smallest 32-bit unsigned number from an input array
// Uses tournament-style comparison with configurable pipeline stages

module min_comparator #(
    parameter ARRAY_SIZE = 16,           // Number of input values (must be power of 2)
    parameter DATA_WIDTH = 32,           // Width of each input value
    parameter PIPELINE_STAGES = 4,       // Number of pipeline stages
    parameter INCLUDE_INDEX = 1          // Include index of minimum value in output
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         valid_in,
    input  wire [ARRAY_SIZE*DATA_WIDTH-1:0] data_in,    // Packed array input
    
    output reg                          valid_out,
    output reg  [DATA_WIDTH-1:0]        min_value,
    output reg  [$clog2(ARRAY_SIZE)-1:0] min_index,     // Index of minimum value
    output reg                          ready           // Ready for next input
);

    // Local parameters
    localparam NUM_LEVELS = $clog2(ARRAY_SIZE);
    localparam TOTAL_COMPARATORS = ARRAY_SIZE - 1;
    
    // Calculate pipeline distribution
    localparam COMPS_PER_STAGE = (NUM_LEVELS + PIPELINE_STAGES - 1) / PIPELINE_STAGES;
    
    // Internal signals
    reg [DATA_WIDTH-1:0] data_array [0:ARRAY_SIZE-1];
    reg [$clog2(ARRAY_SIZE)-1:0] index_array [0:ARRAY_SIZE-1];
    
    // Pipeline registers for values and indices
    reg [DATA_WIDTH-1:0] pipe_values [0:PIPELINE_STAGES][0:ARRAY_SIZE-1];
    reg [$clog2(ARRAY_SIZE)-1:0] pipe_indices [0:PIPELINE_STAGES][0:ARRAY_SIZE-1];
    reg [PIPELINE_STAGES:0] pipe_valid;
    reg [$clog2(ARRAY_SIZE):0] pipe_count [0:PIPELINE_STAGES];
    
    integer i, j, stage, level;
    integer comp_count, stage_comp_count;
    
    // Unpack input data
    always @(*) begin
        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
            data_array[i] = data_in[i*DATA_WIDTH +: DATA_WIDTH];
            index_array[i] = i;
        end
    end
    
    // Initialize first pipeline stage
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pipe_valid[0] <= 1'b0;
            pipe_count[0] <= 0;
        end else begin
            pipe_valid[0] <= valid_in;
            
            if (valid_in) begin
                pipe_count[0] <= ARRAY_SIZE;
                for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                    pipe_values[0][i] <= data_array[i];
                    if (INCLUDE_INDEX)
                        pipe_indices[0][i] <= index_array[i];
                end
            end
        end
    end
    
    // Pipeline stages with tournament comparison
    generate
        genvar stage_idx;
        for (stage_idx = 0; stage_idx < PIPELINE_STAGES; stage_idx = stage_idx + 1) begin : pipeline_stage
            
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    pipe_valid[stage_idx + 1] <= 1'b0;
                    pipe_count[stage_idx + 1] <= 0;
                end else begin
                    pipe_valid[stage_idx + 1] <= pipe_valid[stage_idx];
                    
                    if (pipe_valid[stage_idx]) begin
                        // Perform comparisons for this stage
                        integer current_count = pipe_count[stage_idx];
                        integer next_count = 0;
                        integer comp_idx = 0;
                        
                        // Calculate how many levels to process in this stage
                        integer levels_to_process;
                        integer start_level = stage_idx * COMPS_PER_STAGE;
                        integer end_level = ((stage_idx + 1) * COMPS_PER_STAGE > NUM_LEVELS) ? 
                                                     NUM_LEVELS : (stage_idx + 1) * COMPS_PER_STAGE;
                        
                        levels_to_process = end_level - start_level;
                        
                        // Copy values from previous stage
                        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                            pipe_values[stage_idx + 1][i] <= pipe_values[stage_idx][i];
                            if (INCLUDE_INDEX)
                                pipe_indices[stage_idx + 1][i] <= pipe_indices[stage_idx][i];
                        end
                        
                        // Perform tournament comparisons
                        integer temp_count = current_count;
                        for (level = 0; level < levels_to_process && temp_count > 1; level = level + 1) begin
                            integer pairs = temp_count / 2;
                            for (i = 0; i < pairs; i = i + 1) begin
                                if (pipe_values[stage_idx][2*i] <= pipe_values[stage_idx][2*i + 1]) begin
                                    pipe_values[stage_idx + 1][i] <= pipe_values[stage_idx][2*i];
                                    if (INCLUDE_INDEX)
                                        pipe_indices[stage_idx + 1][i] <= pipe_indices[stage_idx][2*i];
                                end else begin
                                    pipe_values[stage_idx + 1][i] <= pipe_values[stage_idx][2*i + 1];
                                    if (INCLUDE_INDEX)
                                        pipe_indices[stage_idx + 1][i] <= pipe_indices[stage_idx][2*i + 1];
                                end
                            end
                            
                            // Handle odd count
                            if (temp_count % 2 == 1 && temp_count > 1) begin
                                pipe_values[stage_idx + 1][pairs] <= pipe_values[stage_idx][temp_count - 1];
                                if (INCLUDE_INDEX)
                                    pipe_indices[stage_idx + 1][pairs] <= pipe_indices[stage_idx][temp_count - 1];
                                temp_count = pairs + 1;
                            end else begin
                                temp_count = pairs;
                            end
                        end
                        
                        pipe_count[stage_idx + 1] <= temp_count;
                    end
                end
            end
        end
    endgenerate
    
    // Output stage
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            min_value <= {DATA_WIDTH{1'b0}};
            min_index <= {$clog2(ARRAY_SIZE){1'b0}};
            ready <= 1'b1;
        end else begin
            valid_out <= pipe_valid[PIPELINE_STAGES];
            ready <= ~(|pipe_valid[PIPELINE_STAGES-1:0]); // Ready when pipeline is empty
            
            if (pipe_valid[PIPELINE_STAGES]) begin
                min_value <= pipe_values[PIPELINE_STAGES][0];
                if (INCLUDE_INDEX)
                    min_index <= pipe_indices[PIPELINE_STAGES][0];
            end
        end
    end
    
    // Performance counters and monitoring (optional)
    `ifdef INCLUDE_PERFORMANCE_COUNTERS
    reg [31:0] cycle_counter;
    reg [31:0] valid_counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_counter <= 0;
            valid_counter <= 0;
        end else begin
            cycle_counter <= cycle_counter + 1;
            if (valid_out)
                valid_counter <= valid_counter + 1;
        end
    end
    `endif
    
    // Assertions for verification
    `ifdef FORMAL_VERIFICATION
    // Ensure valid_out only asserts when pipeline is full
    assert property (@(posedge clk) disable iff (!rst_n)
        valid_out |-> $past(valid_in, PIPELINE_STAGES));
    
    // Ensure minimum value is actually minimum
    assert property (@(posedge clk) disable iff (!rst_n)
        valid_out |-> (min_value <= $past(data_in[i*DATA_WIDTH +: DATA_WIDTH], PIPELINE_STAGES) 
                      for i in 0 to ARRAY_SIZE-1));
    `endif

endmodule

// Testbench for verification
`ifdef TESTBENCH
module tb_min_comparator;
    parameter ARRAY_SIZE = 16;
    parameter DATA_WIDTH = 32;
    parameter PIPELINE_STAGES = 4;
    
    reg clk, rst_n, valid_in;
    reg [ARRAY_SIZE*DATA_WIDTH-1:0] data_in;
    wire valid_out, ready;
    wire [DATA_WIDTH-1:0] min_value;
    wire [$clog2(ARRAY_SIZE)-1:0] min_index;
    
    // Clock generation
    always #5 clk = ~clk;
    
    // DUT instantiation
    min_comparator #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .PIPELINE_STAGES(PIPELINE_STAGES),
        .INCLUDE_INDEX(1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .data_in(data_in),
        .valid_out(valid_out),
        .min_value(min_value),
        .min_index(min_index),
        .ready(ready)
    );
    
    // Test stimulus
    initial begin
        clk = 0;
        rst_n = 0;
        valid_in = 0;
        data_in = 0;
        
        #20 rst_n = 1;
        #10;
        
        // Test case 1: Sequential values
        data_in = {32'h0000000F, 32'h0000000E, 32'h0000000D, 32'h0000000C,
                   32'h0000000B, 32'h0000000A, 32'h00000009, 32'h00000008,
                   32'h00000007, 32'h00000006, 32'h00000005, 32'h00000004,
                   32'h00000003, 32'h00000002, 32'h00000001, 32'h00000000};
        valid_in = 1;
        #10 valid_in = 0;
        
        // Wait for result
        wait(valid_out);
        $display("Test 1 - Min: %h, Index: %d", min_value, min_index);
        
        // Test case 2: Random values
        #50;
        data_in = {32'h12345678, 32'h87654321, 32'h11111111, 32'h22222222,
                   32'h00000001, 32'hFFFFFFFF, 32'h55555555, 32'hAAAAAAAA,
                   32'h33333333, 32'h44444444, 32'h66666666, 32'h77777777,
                   32'h88888888, 32'h99999999, 32'hBBBBBBBB, 32'hCCCCCCCC};
        valid_in = 1;
        #10 valid_in = 0;
        
        wait(valid_out);
        $display("Test 2 - Min: %h, Index: %d", min_value, min_index);
        
        #100 $finish;
    end
    
endmodule
`endif

