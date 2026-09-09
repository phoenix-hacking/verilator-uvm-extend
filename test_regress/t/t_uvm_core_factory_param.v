// -*- Verilog -*-
// DESCRIPTION: Verilator: UVM parameterized factory specialization and override
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// verilator lint_off DECLFILENAME

// Test requires command line be passed uvm_pkg.sv before this filename

module t_uvm_core_factory_param;
  import uvm_pkg::*;

  class phase_state;
    static bit [31:0] m_seen;

    static function void reset();
      m_seen = '0;
    endfunction

    static function void mark(int unsigned index);
      bit [31:0] mask;
      if (index >= $bits(m_seen)) $fatal(1, "Phase index %0d is out of range", index);
      mask = 32'b1 << index;
      if ((m_seen & mask) != 0) $fatal(1, "Phase index %0d ran more than once", index);
      m_seen |= mask;
    endfunction

    static function bit [31:0] value();
      return m_seen;
    endfunction
  endclass

  class param_object #(int ID = 0) extends uvm_object;
    `uvm_object_param_utils(param_object #(ID))

    function new(string name = "param_object");
      super.new(name);
    endfunction

    function int parameter_identity();
      static int saved_id = ID;
      return saved_id;
    endfunction

    virtual function int signature();
      return ID * 100 + 1;
    endfunction
  endclass

  class param_derived_object #(int ID = 0) extends param_object #(ID);
    `uvm_object_param_utils(param_derived_object #(ID))

    function new(string name = "param_derived_object");
      super.new(name);
    endfunction

    virtual function int signature();
      return ID * 100 + 2;
    endfunction
  endclass

  typedef param_object #(7) param_object_7;
  typedef param_object #(15) param_object_15;
  typedef param_derived_object #(7) param_derived_object_7;
  typedef param_derived_object #(15) param_derived_object_15;

  class param_component #(int ID = 0) extends uvm_component;
    `uvm_component_param_utils(param_component #(ID))

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function int signature();
      return ID * 100 + 1;
    endfunction

    virtual function int unsigned phase_offset();
      return (ID == 17) ? 4 : 16;
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      phase_state::mark(phase_offset());
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      phase_state::mark(phase_offset() + 1);
    endfunction

    virtual function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      phase_state::mark(phase_offset() + 2);
    endfunction

    virtual function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      phase_state::mark(phase_offset() + 3);
    endfunction
  endclass

  class param_derived_component #(int ID = 0) extends param_component #(ID);
    `uvm_component_param_utils(param_derived_component #(ID))

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function int signature();
      return ID * 100 + 2;
    endfunction

    virtual function int unsigned phase_offset();
      return (ID == 9) ? 0 : 12;
    endfunction
  endclass

  typedef param_component #(9) param_component_9;
  typedef param_component #(17) param_component_17;
  typedef param_derived_component #(9) param_derived_component_9;
  typedef param_derived_component #(17) param_derived_component_17;

  class factory_param_test extends uvm_test;
    `uvm_component_utils(factory_param_test)

    param_component_9 m_component_9;
    param_component_17 m_component_17;

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      uvm_object_wrapper base_object_7_wrapper;
      uvm_object_wrapper base_object_15_wrapper;
      uvm_object_wrapper derived_object_7_wrapper;
      uvm_object_wrapper derived_object_15_wrapper;
      uvm_object_wrapper base_component_9_wrapper;
      uvm_object_wrapper base_component_17_wrapper;
      uvm_object_wrapper derived_component_9_wrapper;
      uvm_object_wrapper derived_component_17_wrapper;
      uvm_object raw_object;
      param_object_7 direct_object_7;
      param_object_7 created_object_7;
      param_object_15 created_object_15;
      param_derived_object_7 cast_object_7;
      param_derived_object_15 cast_object_15;
      param_derived_object_15 saved_object_15;
      param_derived_component_9 cast_component_9;
      param_derived_component_17 cast_component_17;

      super.build_phase(phase);
      phase_state::mark(8);

      base_object_7_wrapper = param_object_7::get_type();
      base_object_15_wrapper = param_object_15::get_type();
      derived_object_7_wrapper = param_derived_object_7::get_type();
      derived_object_15_wrapper = param_derived_object_15::get_type();
      base_component_9_wrapper = param_component_9::get_type();
      base_component_17_wrapper = param_component_17::get_type();
      derived_component_9_wrapper = param_derived_component_9::get_type();
      derived_component_17_wrapper = param_derived_component_17::get_type();

      if (base_object_7_wrapper == base_object_15_wrapper)
        `uvm_fatal("PARAM_FACTORY", "Object specializations share a wrapper")
      if (derived_object_7_wrapper == derived_object_15_wrapper)
        `uvm_fatal("PARAM_FACTORY", "Derived object specializations share a wrapper")
      if (base_object_7_wrapper == derived_object_7_wrapper)
        `uvm_fatal("PARAM_FACTORY", "Base and derived ID 7 objects share a wrapper")
      if (base_object_15_wrapper == derived_object_15_wrapper)
        `uvm_fatal("PARAM_FACTORY", "Base and derived ID 15 objects share a wrapper")
      if (base_component_9_wrapper == base_component_17_wrapper)
        `uvm_fatal("PARAM_FACTORY", "Component specializations share a wrapper")
      if (derived_component_9_wrapper == derived_component_17_wrapper)
        `uvm_fatal("PARAM_FACTORY", "Derived component specializations share a wrapper")
      if (base_component_9_wrapper == derived_component_9_wrapper)
        `uvm_fatal("PARAM_FACTORY", "Base and derived ID 9 components share a wrapper")
      if (base_component_17_wrapper == derived_component_17_wrapper)
        `uvm_fatal("PARAM_FACTORY", "Base and derived ID 17 components share a wrapper")

      raw_object = base_object_7_wrapper.create_object("direct_object_7");
      if (!$cast(direct_object_7, raw_object))
        `uvm_fatal("PARAM_FACTORY", "ID 7 wrapper created the wrong specialization")
      if (direct_object_7.get_object_type() != base_object_7_wrapper)
        `uvm_fatal("PARAM_FACTORY", "Direct object returned the wrong wrapper")
      if (direct_object_7.get_name() != "direct_object_7")
        `uvm_fatal("PARAM_FACTORY", "Direct object lost its name")
      if (direct_object_7.signature() != 701)
        `uvm_fatal("PARAM_FACTORY", "Direct object has the wrong signature")
      if (direct_object_7.parameter_identity() != 7)
        `uvm_fatal("PARAM_FACTORY", "ID 7 parameter initializer is wrong")

      param_object_7::type_id::set_type_override(derived_object_7_wrapper);
      param_component_9::type_id::set_type_override(derived_component_9_wrapper);

      created_object_7 = param_object_7::type_id::create("object_7");
      if (created_object_7 == null)
        `uvm_fatal("PARAM_FACTORY", "Factory returned null for object ID 7")
      if (!$cast(cast_object_7, created_object_7))
        `uvm_fatal("PARAM_FACTORY", "Object ID 7 override was not applied")
      if (created_object_7.get_object_type() != derived_object_7_wrapper)
        `uvm_fatal("PARAM_FACTORY", "Object ID 7 returned the wrong wrapper")
      if (created_object_7.get_name() != "object_7")
        `uvm_fatal("PARAM_FACTORY", "Object ID 7 lost its name")
      if (created_object_7.signature() != 702)
        `uvm_fatal("PARAM_FACTORY", "Object ID 7 has the wrong signature")
      if (created_object_7.parameter_identity() != 7)
        `uvm_fatal("PARAM_FACTORY", "Object ID 7 has the wrong parameter identity")

      cast_object_15 = param_derived_object_15::type_id::create("derived_object_15");
      if (cast_object_15 == null)
        `uvm_fatal("PARAM_FACTORY", "Factory returned null for derived object ID 15")
      if (cast_object_15.get_object_type() != derived_object_15_wrapper)
        `uvm_fatal("PARAM_FACTORY", "Derived object ID 15 returned the wrong wrapper")
      if (cast_object_15.signature() != 1502)
        `uvm_fatal("PARAM_FACTORY", "Derived object ID 15 has the wrong signature")
      saved_object_15 = cast_object_15;

      created_object_15 = param_object_15::type_id::create("object_15");
      if (created_object_15 == null)
        `uvm_fatal("PARAM_FACTORY", "Factory returned null for object ID 15")
      if ($cast(cast_object_15, created_object_15))
        `uvm_fatal("PARAM_FACTORY", "Object ID 7 override leaked to ID 15")
      if (cast_object_15 != saved_object_15)
        `uvm_fatal("PARAM_FACTORY", "Failed cast changed its destination")
      if (created_object_15.get_object_type() != base_object_15_wrapper)
        `uvm_fatal("PARAM_FACTORY", "Object ID 15 returned the wrong wrapper")
      if (created_object_15.get_name() != "object_15")
        `uvm_fatal("PARAM_FACTORY", "Object ID 15 lost its name")
      if (created_object_15.signature() != 1501)
        `uvm_fatal("PARAM_FACTORY", "Object ID 15 has the wrong signature")
      if (created_object_15.parameter_identity() != 15)
        `uvm_fatal("PARAM_FACTORY", "Object ID 15 has the wrong parameter identity")

      m_component_9 = param_component_9::type_id::create("component_9", this);
      if (m_component_9 == null)
        `uvm_fatal("PARAM_FACTORY", "Factory returned null for component ID 9")
      if (!$cast(cast_component_9, m_component_9))
        `uvm_fatal("PARAM_FACTORY", "Component ID 9 override was not applied")
      if (m_component_9.get_object_type() != derived_component_9_wrapper)
        `uvm_fatal("PARAM_FACTORY", "Component ID 9 returned the wrong wrapper")
      if (m_component_9.get_name() != "component_9")
        `uvm_fatal("PARAM_FACTORY", "Component ID 9 lost its name")
      if (m_component_9.get_parent() != this)
        `uvm_fatal("PARAM_FACTORY", "Component ID 9 has the wrong parent")
      if (m_component_9.get_full_name() != "uvm_test_top.component_9")
        `uvm_fatal("PARAM_FACTORY", "Component ID 9 has the wrong full name")
      if (m_component_9.signature() != 902)
        `uvm_fatal("PARAM_FACTORY", "Component ID 9 has the wrong signature")

      m_component_17 = param_component_17::type_id::create("component_17", this);
      if (m_component_17 == null)
        `uvm_fatal("PARAM_FACTORY", "Factory returned null for component ID 17")
      if ($cast(cast_component_17, m_component_17))
        `uvm_fatal("PARAM_FACTORY", "Component ID 9 override leaked to ID 17")
      if (m_component_17.get_object_type() != base_component_17_wrapper)
        `uvm_fatal("PARAM_FACTORY", "Component ID 17 returned the wrong wrapper")
      if (m_component_17.get_name() != "component_17")
        `uvm_fatal("PARAM_FACTORY", "Component ID 17 lost its name")
      if (m_component_17.get_parent() != this)
        `uvm_fatal("PARAM_FACTORY", "Component ID 17 has the wrong parent")
      if (m_component_17.get_full_name() != "uvm_test_top.component_17")
        `uvm_fatal("PARAM_FACTORY", "Component ID 17 has the wrong full name")
      if (m_component_17.signature() != 1701)
        `uvm_fatal("PARAM_FACTORY", "Component ID 17 has the wrong signature")
    endfunction

    virtual function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      if ((m_component_9 == null) || (m_component_9.signature() != 902))
        `uvm_fatal("PARAM_FACTORY", "Component ID 9 did not survive through check")
      if ((m_component_17 == null) || (m_component_17.signature() != 1701))
        `uvm_fatal("PARAM_FACTORY", "Component ID 17 did not survive through check")
      phase_state::mark(9);
    endfunction

    virtual function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      phase_state::mark(10);
    endfunction
  endclass

  initial begin
    uvm_root root;
    uvm_report_server report_server;

    phase_state::reset();
    root = uvm_root::get();
    root.set_finish_on_completion(1'b0);
    run_test("factory_param_test");

    if (phase_state::value() != 32'h0000_07ff)
      $fatal(1, "Wrong UVM phase mask: %08x", phase_state::value());
    report_server = uvm_report_server::get_server();
    if ((report_server.get_severity_count(UVM_ERROR) != 0)
        || (report_server.get_severity_count(UVM_FATAL) != 0))
      $fatal(1, "UVM reported an error or fatal");

    $write("** UVM FACTORY PARAM PASSED **\n");
    $finish;
  end
endmodule
