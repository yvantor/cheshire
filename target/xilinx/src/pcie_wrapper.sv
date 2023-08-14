// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Cyril Koenig <cykoenig@iis.ee.ethz.ch>

// Todo : Benchmark different AXI ID resizer width

`include "cheshire/typedef.svh"
`include "phy_definitions.svh"
`include "common_cells/registers.svh"

module pcie_wrapper #(
    parameter type axi_soc_aw_chan_t = logic,
    parameter type axi_soc_w_chan_t  = logic,
    parameter type axi_soc_b_chan_t  = logic,
    parameter type axi_soc_ar_chan_t = logic,
    parameter type axi_soc_r_chan_t  = logic,
    parameter type axi_soc_req_t     = logic,
    parameter type axi_soc_resp_t    = logic
) (
    // System reset
    input                 sys_rst_i,
    input                 pcie_clk_i,
    input                 pcie_clk_gt_i,
    // Controller reset
    input                 soc_resetn_i,
    input                 soc_clk_i,
    // Phy interfaces
    output [3 : 0]        pcie_txp,
    output [3 : 0]        pcie_txn,
    input  [3 : 0]        pcie_rxp,
    input  [3 : 0]        pcie_rxn,

    // Axi interface
    input  axi_soc_req_t   soc_pcie_req_i,
    output axi_soc_resp_t  soc_pcie_rsp_o,
    output axi_soc_req_t   pcie_soc_req_o,
    input  axi_soc_resp_t  pcie_soc_rsp_i
);

  ////////////////////////////////////
  // Configurations and definitions //
  ////////////////////////////////////

  typedef struct packed {
    bit EnCDC;
    integer IdWidth;
    integer AddrWidth;
    integer DataWidth;
    integer StrobeWidth;
  } pcie_cfg_t;

`ifdef TARGET_VCU128
  localparam pcie_cfg_t cfg = '{
    EnCDC         : 1, // 125 MHz axi
    IdWidth       : 4,
    AddrWidth     : 32,
    DataWidth     : 64,
    StrobeWidth   : 8
  };
`endif

  localparam SoC_DataWidth = $bits(soc_pcie_req_i.w.data);
  localparam SoC_IdWidth   = $bits(soc_pcie_req_i.ar.id);
  localparam SoC_UserWidth = $bits(soc_pcie_req_i.ar.user);
  localparam SoC_AddrWidth = $bits(soc_pcie_req_i.ar.addr);

  // Define data type after data width resizer
  `AXI_TYPEDEF_ALL(axi_dw, logic[SoC_AddrWidth-1:0], logic[SoC_IdWidth-1:0],
                   logic[cfg.DataWidth-1:0], logic[cfg.StrobeWidth-1:0],
                   logic[SoC_UserWidth-1:0])

  // Define data type after data & id width resizers
  `AXI_TYPEDEF_ALL(axi_dw_iw, logic[SoC_AddrWidth-1:0], logic[cfg.IdWidth-1:0],
                   logic[cfg.DataWidth-1:0], logic[cfg.StrobeWidth-1:0],
                   logic[SoC_UserWidth-1:0])

  // Define configuration type 32-bits AXI
  `AXI_TYPEDEF_ALL(axi_config, logic[31:0], logic[SoC_IdWidth-1:0],
                   logic[31:0], logic[3:0], logic[SoC_UserWidth-1:0])

  // Define configuration type 32-bits AXI-lite
  `AXI_LITE_TYPEDEF_ALL(axil_config, logic[31:0], logic[31:0], logic[3:0])

  // Clock on which is clocked the DRAM AXI
  logic pcie_axi_clk, pcie_rst_o;

  //////////////////////
  // Upstream signals //
  //////////////////////

  // Signals before resizing
  axi_soc_req_t  soc_dresizer_req;
  axi_soc_resp_t soc_dresizer_rsp;

  // Signals after data width resizing
  axi_dw_req_t  dresizer_iresizer_req;
  axi_dw_resp_t dresizer_iresizer_rsp;

  // Signals after id width resizing
  axi_dw_iw_req_t  iresizer_cdc_req, cdc_pcie_req;
  axi_dw_iw_resp_t iresizer_cdc_rsp, cdc_pcie_rsp;

  // Entry signals
  assign soc_dresizer_req = soc_pcie_req_i;
  assign soc_pcie_rsp_o = soc_dresizer_rsp;

  ////////////////////////
  // Downstream signals //
  ////////////////////////

  // Signals before resizing
  axi_soc_req_t  dresizer_soc_req;
  axi_soc_resp_t dresizer_soc_rsp;

  // Signals after data width resizing
  axi_dw_req_t  iresizer_dresizer_req;
  axi_dw_resp_t iresizer_dresizer_rsp;

  // Signals after id width resizing
  axi_dw_iw_req_t  cdc_iresizer_req, pcie_cdc_req;
  axi_dw_iw_resp_t cdc_iresizer_rsp, pcie_cdc_rsp;

  // Exit signals
  assign pcie_soc_req_o = dresizer_soc_req;
  assign dresizer_soc_rsp = pcie_soc_rsp_i;

  ///////////////////////////
  // Configuration signals //
  ///////////////////////////

  axi_config_req_t   axi_config_req;
  axi_config_resp_t  axi_config_rsp;

  axil_config_req_t  axil_config_req;
  axil_config_resp_t axil_config_rsp;

  /////////////////////////////////////
  // Instianciate data width resizer //
  /////////////////////////////////////

  // Upstream

  if (cfg.DataWidth != SoC_DataWidth) begin : gen_upstream_dw_converter
    axi_dw_converter #(
        .AxiMaxReads        (8),
        .AxiSlvPortDataWidth(SoC_DataWidth),
        .AxiMstPortDataWidth(cfg.DataWidth),
        .AxiAddrWidth       (SoC_AddrWidth),
        .AxiIdWidth         (SoC_IdWidth  ),
        // Common aw, ar, b
        .aw_chan_t          (axi_soc_aw_chan_t),
        .b_chan_t           (axi_soc_b_chan_t),
        .ar_chan_t          (axi_soc_ar_chan_t),
        // Master w, r
        .mst_w_chan_t       (axi_dw_w_chan_t),
        .mst_r_chan_t       (axi_dw_r_chan_t),
        .axi_mst_req_t      (axi_dw_req_t),
        .axi_mst_resp_t     (axi_dw_resp_t),
        // Slave w, r
        .slv_w_chan_t       (axi_soc_w_chan_t),
        .slv_r_chan_t       (axi_soc_r_chan_t),
        .axi_slv_req_t      (axi_soc_req_t),
        .axi_slv_resp_t     (axi_soc_resp_t)
    ) upstream_axi_dw_converter (
        .clk_i     (soc_clk_i),
        .rst_ni    (soc_resetn_i),
        .slv_req_i (soc_dresizer_req),
        .slv_resp_o(soc_dresizer_rsp),
        .mst_req_o (dresizer_iresizer_req),
        .mst_resp_i(dresizer_iresizer_rsp)
    );
  end else begin : gen_no_upstream_axi_dw_converter
    assign dresizer_iresizer_req = soc_dresizer_req;
    assign soc_dresizer_rsp      = dresizer_iresizer_rsp;
  end

  // Downstream

  if (cfg.DataWidth != SoC_DataWidth) begin : gen_downstream_dw_converter
    axi_dw_converter #(
        .AxiMaxReads        (8),
        .AxiSlvPortDataWidth(cfg.DataWidth),
        .AxiMstPortDataWidth(SoC_DataWidth),
        .AxiAddrWidth       (SoC_AddrWidth),
        .AxiIdWidth         (SoC_IdWidth  ),
        // Common aw, ar, b
        .aw_chan_t          (axi_soc_aw_chan_t),
        .b_chan_t           (axi_soc_b_chan_t),
        .ar_chan_t          (axi_soc_ar_chan_t),
        // Master w, r
        .mst_w_chan_t       (axi_soc_w_chan_t),
        .mst_r_chan_t       (axi_soc_r_chan_t),
        .axi_mst_req_t      (axi_soc_req_t),
        .axi_mst_resp_t     (axi_soc_resp_t),
        // Slave w, r
        .slv_w_chan_t       (axi_dw_w_chan_t),
        .slv_r_chan_t       (axi_dw_r_chan_t),
        .axi_slv_req_t      (axi_dw_req_t),
        .axi_slv_resp_t     (axi_dw_resp_t)
    ) i_downstream_axi_dw_converter (
        .clk_i     (soc_clk_i),
        .rst_ni    (soc_resetn_i),
        .slv_req_i (iresizer_dresizer_req),
        .slv_resp_o(iresizer_dresizer_rsp),
        .mst_req_o (dresizer_soc_req),
        .mst_resp_i(dresizer_soc_rsp)
    );
  end else begin : gen_no_downstream_dw_converter
    assign dresizer_soc_req      = iresizer_dresizer_req;
    assign iresizer_dresizer_rsp = dresizer_soc_rsp;
  end

  /////////////////
  // ID resizer  //
  /////////////////

// Upstream

if (cfg.IdWidth != SoC_IdWidth) begin : gen_upstream_iw_converter
  axi_iw_converter #(
    .AxiAddrWidth          ( SoC_AddrWidth    ),
    .AxiDataWidth          ( cfg.DataWidth    ),
    .AxiUserWidth          ( SoC_UserWidth    ),
    .AxiSlvPortIdWidth     ( SoC_IdWidth      ),
    .AxiSlvPortMaxUniqIds  ( 1                ),
    .AxiSlvPortMaxTxnsPerId( 1                ),
    .AxiSlvPortMaxTxns     ( 1                ),
    .AxiMstPortIdWidth     ( cfg.IdWidth      ),
    .AxiMstPortMaxUniqIds  ( 1                ),
    .AxiMstPortMaxTxnsPerId( 1                ),
    .slv_req_t             ( axi_dw_req_t     ),
    .slv_resp_t            ( axi_dw_resp_t    ),
    .mst_req_t             ( axi_dw_iw_req_t  ),
    .mst_resp_t            ( axi_dw_iw_resp_t )
  ) i_upstream_axi_iw_convert (
    .clk_i      ( soc_clk_i             ),
    .rst_ni     ( soc_resetn_i          ),
    .slv_req_i  ( dresizer_iresizer_req ),
    .slv_resp_o ( dresizer_iresizer_rsp ),
    .mst_req_o  ( iresizer_cdc_req      ),
    .mst_resp_i ( iresizer_cdc_rsp      )
  );
  end else begin : gen_no_upstream_iw_converter
    assign iresizer_cdc_req = dresizer_iresizer_req;
    assign dresizer_iresizer_rsp = iresizer_cdc_rsp;
  end

// Dowstream

if (cfg.IdWidth != SoC_IdWidth) begin : gen_downstream_iw_converter
  axi_iw_converter #(
    .AxiAddrWidth          ( SoC_AddrWidth    ),
    .AxiDataWidth          ( cfg.DataWidth    ),
    .AxiUserWidth          ( SoC_UserWidth    ),
    .AxiSlvPortIdWidth     ( cfg.IdWidth      ),
    .AxiSlvPortMaxUniqIds  ( 1                ),
    .AxiSlvPortMaxTxnsPerId( 1                ),
    .AxiSlvPortMaxTxns     ( 1                ),
    .AxiMstPortIdWidth     ( SoC_IdWidth      ),
    .AxiMstPortMaxUniqIds  ( 1                ),
    .AxiMstPortMaxTxnsPerId( 1                ),
    .slv_req_t             ( axi_dw_iw_req_t     ),
    .slv_resp_t            ( axi_dw_iw_resp_t    ),
    .mst_req_t             ( axi_dw_req_t  ),
    .mst_resp_t            ( axi_dw_resp_t )
  ) i_downstream_axi_iw_convert (
    .clk_i      ( soc_clk_i             ),
    .rst_ni     ( soc_resetn_i          ),
    .slv_req_i  ( cdc_iresizer_req      ),
    .slv_resp_o ( cdc_iresizer_rsp      ),
    .mst_req_o  ( iresizer_dresizer_req ),
    .mst_resp_i ( iresizer_dresizer_rsp )
  );
  end else begin : gen_no_upstream_iw_converter
    assign iresizer_dresizer_req = cdc_iresizer_req;
    assign cdc_iresizer_rsp      = iresizer_dresizer_rsp;
  end

  //////////////////////
  // Instianciate CDC //
  //////////////////////

  // Upstream

  if (cfg.EnCDC) begin : gen_upstream_cdc
    axi_cdc #(
        .aw_chan_t (axi_dw_iw_aw_chan_t),
        .w_chan_t  (axi_dw_iw_w_chan_t),
        .b_chan_t  (axi_dw_iw_b_chan_t),
        .ar_chan_t (axi_dw_iw_ar_chan_t),
        .r_chan_t  (axi_dw_iw_r_chan_t),
        .axi_req_t (axi_dw_iw_req_t),
        .axi_resp_t(axi_dw_iw_resp_t),
        .LogDepth  (4)
    ) i_upstream_axi_cdc (
        .src_clk_i (soc_clk_i),
        .src_rst_ni(soc_resetn_i),
        .src_req_i (iresizer_cdc_req),
        .src_resp_o(iresizer_cdc_rsp),
        .dst_clk_i (pcie_axi_clk),
        .dst_rst_ni(~pcie_rst_o),
        .dst_req_o (cdc_pcie_req),
        .dst_resp_i(cdc_pcie_rsp)
    );
  end else begin : gen_no_upstream_cdc
    assign cdc_pcie_req     = iresizer_cdc_req;
    assign iresizer_cdc_rsp = cdc_pcie_rsp;
  end

  // Downstream

  if (cfg.EnCDC) begin : gen_downstream_cdc
    axi_cdc #(
        .aw_chan_t (axi_dw_iw_aw_chan_t),
        .w_chan_t  (axi_dw_iw_w_chan_t),
        .b_chan_t  (axi_dw_iw_b_chan_t),
        .ar_chan_t (axi_dw_iw_ar_chan_t),
        .r_chan_t  (axi_dw_iw_r_chan_t),
        .axi_req_t (axi_dw_iw_req_t),
        .axi_resp_t(axi_dw_iw_resp_t),
        .LogDepth  (4)
    ) i_axi_downstream_cdc (
        .src_clk_i (pcie_axi_clk),
        .src_rst_ni(~pcie_rst_o),
        .src_req_i (pcie_cdc_req),
        .src_resp_o(pcie_cdc_rsp),
        .dst_clk_i (soc_clk_i),
        .dst_rst_ni(soc_resetn_i),
        .dst_req_o (cdc_iresizer_req),
        .dst_resp_i(cdc_iresizer_rsp)
    );
  end else begin : gen_no_downstream_cdc
    assign cdc_iresizer_req = pcie_cdc_req;
    assign pcie_cdc_rsp     = cdc_iresizer_rsp;
  end

  ///////////////////////
  // Instianciate XDMA //
  ///////////////////////

  xlnx_xdma i_xdma (
    .sys_clk     ( pcie_clk_i       ),
    .sys_clk_gt  ( pcie_clk_gt_i    ),
    .sys_rst_n   ( soc_resetn_i ),
    .axi_aclk    ( pcie_axi_clk ),
    .axi_aresetn ( pcie_rst_o   ),
    // Downstream
    .m_axib_awid      (  pcie_cdc_req.aw.id     ),
    .m_axib_awaddr    (  pcie_cdc_req.aw.addr   ),
    .m_axib_awlen     (  pcie_cdc_req.aw.len    ),
    .m_axib_awsize    (  pcie_cdc_req.aw.size   ),
    .m_axib_awburst   (  pcie_cdc_req.aw.burst  ),
    .m_axib_awprot    (  pcie_cdc_req.aw.prot   ),
    .m_axib_awvalid   (  pcie_cdc_req.aw_valid  ),
    .m_axib_awready   (  pcie_cdc_rsp.aw_ready  ),
    .m_axib_awlock    (  pcie_cdc_req.aw.lock   ),
    .m_axib_awcache   (  pcie_cdc_req.aw.cache  ),
    .m_axib_wdata     (  pcie_cdc_req.w.data    ),
    .m_axib_wstrb     (  pcie_cdc_req.w.strb    ),
    .m_axib_wlast     (  pcie_cdc_req.w.last    ),
    .m_axib_wvalid    (  pcie_cdc_req.w_valid   ),
    .m_axib_wready    (  pcie_cdc_rsp.w_ready   ),
    .m_axib_bid       (  pcie_cdc_rsp.b.id      ),
    .m_axib_bresp     (  pcie_cdc_rsp.b.resp    ),
    .m_axib_bvalid    (  pcie_cdc_rsp.b_valid   ),
    .m_axib_bready    (  pcie_cdc_req.b_ready   ),
    .m_axib_arid      (  pcie_cdc_req.ar.id     ),
    .m_axib_araddr    (  pcie_cdc_req.ar.addr   ),
    .m_axib_arlen     (  pcie_cdc_req.ar.len    ),
    .m_axib_arsize    (  pcie_cdc_req.ar.size   ),
    .m_axib_arburst   (  pcie_cdc_req.ar.burst  ),
    .m_axib_arprot    (  pcie_cdc_req.ar.prot   ),
    .m_axib_arvalid   (  pcie_cdc_req.ar_valid  ),
    .m_axib_arready   (  pcie_cdc_rsp.ar_ready  ),
    .m_axib_arlock    (  pcie_cdc_req.ar.lock   ),
    .m_axib_arcache   (  pcie_cdc_req.ar.cache  ),
    .m_axib_rid       (  pcie_cdc_rsp.r.id      ),
    .m_axib_rdata     (  pcie_cdc_rsp.r.data    ),
    .m_axib_rresp     (  pcie_cdc_rsp.r.resp    ),
    .m_axib_rlast     (  pcie_cdc_rsp.r.last    ),
    .m_axib_rvalid    (  pcie_cdc_rsp.r_valid   ),
    .m_axib_rready    (  pcie_cdc_req.r_ready   ),
    // Upstream
    .s_axib_awid      (  cdc_pcie_req.aw.id      ),
    .s_axib_awaddr    (  cdc_pcie_req.aw.addr    ),
    .s_axib_awregion  (  cdc_pcie_req.aw.region  ),
    .s_axib_awlen     (  cdc_pcie_req.aw.len     ),
    .s_axib_awsize    (  cdc_pcie_req.aw.size    ),
    .s_axib_awburst   (  cdc_pcie_req.aw.burst   ),
    .s_axib_awvalid   (  cdc_pcie_req.aw_valid   ),
    .s_axib_wdata     (  cdc_pcie_req.w.data     ),
    .s_axib_wstrb     (  cdc_pcie_req.w.strb     ),
    .s_axib_wlast     (  cdc_pcie_req.w.last     ),
    .s_axib_wvalid    (  cdc_pcie_req.w_valid    ),
    .s_axib_bready    (  cdc_pcie_req.b_ready    ),
    .s_axib_arid      (  cdc_pcie_req.ar.id      ),
    .s_axib_araddr    (  cdc_pcie_req.ar.addr    ),
    .s_axib_arregion  (  cdc_pcie_req.ar.region  ),
    .s_axib_arlen     (  cdc_pcie_req.ar.len     ),
    .s_axib_arsize    (  cdc_pcie_req.ar.size    ),
    .s_axib_arburst   (  cdc_pcie_req.ar.burst   ),
    .s_axib_arvalid   (  cdc_pcie_req.ar_valid   ),
    .s_axib_rready    (  cdc_pcie_req.r_ready    ),
    .s_axib_awready   (  cdc_pcie_rsp.aw_ready   ),
    .s_axib_wready    (  cdc_pcie_rsp.w_ready    ),
    .s_axib_bid       (  cdc_pcie_rsp.b.id       ),
    .s_axib_bresp     (  cdc_pcie_rsp.b.resp     ),
    .s_axib_bvalid    (  cdc_pcie_rsp.b_valid    ),
    .s_axib_arready   (  cdc_pcie_rsp.ar_ready   ),
    .s_axib_rid       (  cdc_pcie_rsp.r.id       ),
    .s_axib_rdata     (  cdc_pcie_rsp.r.data     ),
    .s_axib_rresp     (  cdc_pcie_rsp.r.resp     ),
    .s_axib_rlast     (  cdc_pcie_rsp.r.last     ),
    .s_axib_rvalid    (  cdc_pcie_rsp.r_valid    ),
    // Config
    .s_axil_awaddr    (  axil_config_req.aw.addr  ),
    .s_axil_awprot    (  axil_config_req.aw.prot  ),
    .s_axil_awvalid   (  axil_config_req.aw_valid  ),
    .s_axil_awready   (  axil_config_rsp.aw_ready  ),
    .s_axil_wdata     (  axil_config_req.w.data  ),
    .s_axil_wstrb     (  axil_config_req.w.strb  ),
    .s_axil_wvalid    (  axil_config_req.w_valid  ),
    .s_axil_wready    (  axil_config_rsp.w_ready  ),
    .s_axil_bvalid    (  axil_config_rsp.b_valid  ),
    .s_axil_bresp     (  axil_config_rsp.b.resp  ),
    .s_axil_bready    (  axil_config_req.b_ready  ),
    .s_axil_araddr    (  axil_config_req.ar.addr  ),
    .s_axil_arprot    (  axil_config_req.ar.prot  ),
    .s_axil_arvalid   (  axil_config_req.ar_valid  ),
    .s_axil_arready   (  axil_config_rsp.ar_ready  ),
    .s_axil_rdata     (  axil_config_rsp.r.data  ),
    .s_axil_rresp     (  axil_config_rsp.r.resp  ),
    .s_axil_rvalid    (  axil_config_rsp.r_valid  ),
    .s_axil_rready    (  axil_config_req.r_ready  ),
    // Phy
    .pci_exp_txp (  pcie_txp  ),
    .pci_exp_txn (  pcie_txn  ),
    .pci_exp_rxp (  pcie_rxp  ),
    .pci_exp_rxn (  pcie_rxn  )
  );

  ////////////////////////
  // Configuration path //
  ////////////////////////

  axi_to_axi_lite # (
    .AxiAddrWidth    (32),
    .AxiDataWidth    (32),
    .AxiIdWidth      (SoC_IdWidth),
    .AxiUserWidth    (SoC_UserWidth),
    .AxiMaxWriteTxns (1),
    .AxiMaxReadTxns  (1),
    .FallThrough     (1),
    .full_req_t      (axi_config_req_t),
    .full_resp_t     (axi_config_resp_t),
    .lite_req_t      (axil_config_req_t),
    .lite_resp_t     (axil_config_resp_t)
  ) i_axi_to_axi_lite (
    .clk_i(pcie_axi_clk),
    .rst_ni(pcie_rst_o),
    .test_i(0),
    .slv_req_i('0),
    .slv_resp_o(),
    .mst_req_o(axil_config_req),
    .mst_resp_i(axil_config_rsp)
  );

endmodule
