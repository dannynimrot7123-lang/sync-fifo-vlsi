`timescale 1ns/1ps
// =============================================================================
// sync_fifo_tb.v - self-checking testbench with a reference model (scoreboard)
// Tests: reset, fill-to-full, overflow, drain-to-empty, underflow, almost
// flags, simultaneous read/write, pointer wrap-around, constrained-random.
// Stimulus is driven on negedge clk (race-free); outputs checked next negedge.
// =============================================================================
module sync_fifo_tb;
    localparam DW = 8, DEPTH = 8, AF = 2, AE = 2;

    reg clk = 0, rst_n = 0;
    reg wr_en = 0, rd_en = 0;
    reg [DW-1:0] wr_data = 0;
    wire [DW-1:0] rd_data;
    wire full, empty, almost_full, almost_empty, overflow, underflow;
    wire [$clog2(DEPTH+1)-1:0] count;

    sync_fifo #(.DATA_WIDTH(DW), .DEPTH(DEPTH), .AF_MARGIN(AF), .AE_MARGIN(AE)) dut (
        .clk(clk), .rst_n(rst_n), .wr_en(wr_en), .wr_data(wr_data),
        .rd_en(rd_en), .rd_data(rd_data), .full(full), .empty(empty),
        .almost_full(almost_full), .almost_empty(almost_empty),
        .overflow(overflow), .underflow(underflow), .count(count));

    always #5 clk = ~clk;

    // ---- reference model ----
    reg [DW-1:0] model [0:DEPTH-1];
    integer mwr = 0, mrd = 0, mcount = 0;
    integer errors = 0, checks = 0;
    reg [DW-1:0] exp_data;
    reg exp_rd, exp_wr, exp_ovf, exp_unf;

    task cycle(input w, input [DW-1:0] d, input r);
        begin
            wr_en = w; wr_data = d; rd_en = r;
            exp_wr  = w && (mcount < DEPTH);
            exp_rd  = r && (mcount > 0);
            exp_ovf = w && (mcount == DEPTH);
            exp_unf = r && (mcount == 0);
            if (exp_rd) exp_data = model[mrd];
            if (exp_wr) begin model[mwr] = d; mwr = (mwr + 1) % DEPTH; end
            if (exp_rd) mrd = (mrd + 1) % DEPTH;
            mcount = mcount + (exp_wr ? 1 : 0) - (exp_rd ? 1 : 0);
            @(negedge clk);          // posedge happened in between
            check;
        end
    endtask

    task check;
        begin
            checks = checks + 1;
            if (count !== mcount)                       begin errors = errors + 1; $display("[FAIL] t=%0t count=%0d exp=%0d", $time, count, mcount); end
            if (full !== (mcount == DEPTH))             begin errors = errors + 1; $display("[FAIL] t=%0t full flag", $time); end
            if (empty !== (mcount == 0))                begin errors = errors + 1; $display("[FAIL] t=%0t empty flag", $time); end
            if (almost_full !== (mcount >= DEPTH-AF))   begin errors = errors + 1; $display("[FAIL] t=%0t almost_full flag", $time); end
            if (almost_empty !== (mcount <= AE))        begin errors = errors + 1; $display("[FAIL] t=%0t almost_empty flag", $time); end
            if (overflow !== exp_ovf)                   begin errors = errors + 1; $display("[FAIL] t=%0t overflow flag", $time); end
            if (underflow !== exp_unf)                  begin errors = errors + 1; $display("[FAIL] t=%0t underflow flag", $time); end
            if (exp_rd && rd_data !== exp_data)         begin errors = errors + 1; $display("[FAIL] t=%0t rd_data=%h exp=%h", $time, rd_data, exp_data); end
        end
    endtask

    task idle; begin cycle(0, 0, 0); end endtask

    integer i, seed;
    initial begin
        $dumpfile("sync_fifo.vcd");
        $dumpvars(0, sync_fifo_tb);
        seed = 32'hC0FFEE;

        repeat (3) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        $display("[TEST 1] Reset state: empty, not full");
        check_reset;

        $display("[TEST 2] Fill to full (%0d writes) + almost_full", DEPTH);
        for (i = 0; i < DEPTH; i = i + 1) cycle(1, 8'hA0 + i, 0);
        if (!full) begin errors = errors + 1; $display("[FAIL] not full"); end

        $display("[TEST 3] Overflow: write while full is ignored");
        cycle(1, 8'hEE, 0);
        cycle(1, 8'hEF, 0);

        $display("[TEST 4] Drain to empty + almost_empty (data order check)");
        for (i = 0; i < DEPTH; i = i + 1) cycle(0, 0, 1);
        if (!empty) begin errors = errors + 1; $display("[FAIL] not empty"); end

        $display("[TEST 5] Underflow: read while empty is ignored");
        cycle(0, 0, 1);
        cycle(0, 0, 1);

        $display("[TEST 6] Simultaneous read + write (count steady)");
        for (i = 0; i < 4; i = i + 1) cycle(1, 8'h10 + i, 0);
        for (i = 0; i < 12; i = i + 1) cycle(1, 8'h50 + i, 1);
        for (i = 0; i < 4;  i = i + 1) cycle(0, 0, 1);

        $display("[TEST 7] Simultaneous rd+wr when full / when empty");
        for (i = 0; i < DEPTH; i = i + 1) cycle(1, i, 0);
        cycle(1, 8'h77, 1);          // full: read wins, write dropped
        while (mcount > 0) cycle(0, 0, 1);
        cycle(1, 8'h99, 1);          // empty: write accepted, read ignored
        cycle(0, 0, 1);

        $display("[TEST 8] Pointer wrap-around (3 x DEPTH words)");
        for (i = 0; i < 3*DEPTH; i = i + 1) begin
            cycle(1, i[7:0] ^ 8'h5A, 0);
            cycle(0, 0, 1);
        end

        $display("[TEST 9] Constrained-random (2000 cycles)");
        for (i = 0; i < 2000; i = i + 1)
            cycle(($random(seed) % 100) < 55, $random(seed), ($random(seed) % 100) < 45);

        $display("[TEST 10] Mid-operation reset");
        for (i = 0; i < 5; i = i + 1) cycle(1, i, 0);
        wr_en = 0; rd_en = 0;
        rst_n = 0; @(negedge clk); @(negedge clk); rst_n = 1;
        mwr = 0; mrd = 0; mcount = 0; exp_rd = 0; exp_ovf = 0; exp_unf = 0;
        @(negedge clk);
        check_reset;
        idle;

        $display("\n==========================================");
        $display("Checks run: %0d", checks);
        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d ERROR(S)", errors);
        $display("==========================================");
        $finish;
    end

    task check_reset;
        begin
            if (!(empty && !full && count == 0)) begin
                errors = errors + 1; $display("[FAIL] reset state wrong");
            end
        end
    endtask

    initial begin #2000000; $display("[TIMEOUT]"); $finish; end
endmodule
