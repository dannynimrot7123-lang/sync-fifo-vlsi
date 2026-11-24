// =============================================================================
// sync_fifo.v  -  Parameterized Synchronous FIFO (single clock)
//
// Parameters : DATA_WIDTH, DEPTH, AF_MARGIN, AE_MARGIN
// Flags      : full, empty, almost_full, almost_empty (+ overflow/underflow)
//
//   empty        : count == 0
//   full         : count == DEPTH
//   almost_empty : count <= AE_MARGIN
//   almost_full  : count >= DEPTH - AF_MARGIN
//
// Writes when full and reads when empty are ignored and raise a sticky-free
// 1-cycle overflow / underflow pulse. Simultaneous read+write is supported
// (count unchanged). Read data is registered (valid the cycle after rd_en).
// =============================================================================
module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16,
    parameter AF_MARGIN  = 2,   // almost_full  asserts when this many slots remain
    parameter AE_MARGIN  = 2    // almost_empty asserts when this many entries remain
)(
    input  wire                         clk,
    input  wire                         rst_n,      // active-low synchronous reset
    input  wire                         wr_en,
    input  wire [DATA_WIDTH-1:0]        wr_data,
    input  wire                         rd_en,
    output reg  [DATA_WIDTH-1:0]        rd_data,
    output wire                         full,
    output wire                         empty,
    output wire                         almost_full,
    output wire                         almost_empty,
    output reg                          overflow,
    output reg                          underflow,
    output wire [$clog2(DEPTH+1)-1:0]   count
);
    localparam AW = $clog2(DEPTH);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [AW-1:0]         wr_ptr, rd_ptr;
    reg [$clog2(DEPTH+1)-1:0] cnt;

    assign count        = cnt;
    assign full         = (cnt == DEPTH);
    assign empty        = (cnt == 0);
    assign almost_full  = (cnt >= DEPTH - AF_MARGIN);
    assign almost_empty = (cnt <= AE_MARGIN);

    wire do_wr = wr_en && !full;
    wire do_rd = rd_en && !empty;

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr    <= 0;
            rd_ptr    <= 0;
            cnt       <= 0;
            rd_data   <= 0;
            overflow  <= 1'b0;
            underflow <= 1'b0;
        end else begin
            overflow  <= wr_en && full;
            underflow <= rd_en && empty;

            if (do_wr) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1'b1;
            end
            if (do_rd) begin
                rd_data <= mem[rd_ptr];
                rd_ptr  <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1'b1;
            end

            case ({do_wr, do_rd})
                2'b10:   cnt <= cnt + 1'b1;
                2'b01:   cnt <= cnt - 1'b1;
                default: cnt <= cnt;   // idle or simultaneous rd+wr
            endcase
        end
    end
endmodule
