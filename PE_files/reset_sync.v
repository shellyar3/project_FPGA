module reset_sync (
    input wire clk,
    input wire async_rst,
    output wire sync_rst // AASD reset
);

    reg rst_meta, rst_sync;

    always @(posedge clk or negedge async_rst) begin
        if (!async_rst) begin
            rst_meta <= 1'b0;
            rst_sync <= 1'b0;
        end
        else begin
            rst_meta <= 1'b1;
            rst_sync <= rst_meta;
        end
    end

    assign sync_rst = rst_sync;

endmodule