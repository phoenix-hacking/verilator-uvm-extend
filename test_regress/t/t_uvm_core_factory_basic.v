// -*- Verilog -*-
// DESCRIPTION: Verilator: UVM 2020.3.1 factory override and creation
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

// Test requires command line be passed uvm_pkg.sv before this filename

// verilator lint_off DECLFILENAME

module t;
  import uvm_pkg::*;

  class base_item extends uvm_object;
    `uvm_object_utils(base_item)

    function new(string name = "base_item");
      super.new(name);
    endfunction
  endclass

  class derived_item extends base_item;
    `uvm_object_utils(derived_item)

    function new(string name = "derived_item");
      super.new(name);
    endfunction
  endclass

  class named_base_item extends uvm_object;
    `uvm_object_utils(named_base_item)

    function new(string name = "named_base_item");
      super.new(name);
    endfunction
  endclass

  class named_derived_item extends named_base_item;
    `uvm_object_utils(named_derived_item)

    function new(string name = "named_derived_item");
      super.new(name);
    endfunction
  endclass

  class factory_test extends uvm_test;
    `uvm_component_utils(factory_test)

    function new(string name, uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      uvm_factory factory;
      uvm_object created;
      derived_item overridden;
      named_derived_item named_overridden;
      uvm_object_wrapper wrapper;

      super.build_phase(phase);
      factory = uvm_factory::get();
      base_item::type_id::set_type_override(derived_item::get_type());
      factory.set_type_override_by_name("named_base_item", "named_derived_item");

      wrapper = base_item::get_type();
      if (wrapper.get_type_name() != "base_item")
        `uvm_fatal("FACTORY", "get_type returned the wrong wrapper")
      created = wrapper.create_object("wrapper_create");
      if (created.get_type_name() != "base_item")
        `uvm_fatal("FACTORY", "wrapper create_object returned the wrong type")
      if (created.get_name() != "wrapper_create")
        `uvm_fatal("FACTORY", "wrapper create_object did not preserve the object name")

      created = base_item::type_id::create("typed_create");
      if (!$cast(overridden, created))
        `uvm_fatal("FACTORY", "type_id::create did not apply the override")
      if (created.get_object_type() != derived_item::get_type())
        `uvm_fatal("FACTORY", "get_object_type did not return the override wrapper")
      if (created.get_type_name() != "derived_item")
        `uvm_fatal("FACTORY", "get_type_name did not return the override type name")
      if (created.get_name() != "typed_create")
        `uvm_fatal("FACTORY", "type_id::create did not preserve the object name")

      created = factory.create_object_by_name("named_base_item", "", "name_create");
      if (!$cast(named_overridden, created))
        `uvm_fatal("FACTORY", "create_object_by_name did not apply the override")
      if (created.get_type_name() != "named_derived_item")
        `uvm_fatal("FACTORY", "name override returned the wrong type name")
      if (created.get_name() != "name_create")
        `uvm_fatal("FACTORY", "create_object_by_name did not preserve the object name")
    endfunction

    virtual function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      $write("** UVM FACTORY BASIC PASSED **\n");
    endfunction
  endclass

  initial begin
    run_test("factory_test");
  end
endmodule
