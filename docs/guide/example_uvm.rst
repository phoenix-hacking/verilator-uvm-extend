..
   SPDX-FileCopyrightText: 2026-2026 Wilson Snyder
   SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

.. _example uvm source execution:

Example UVM Source Execution
============================

The ``examples/make_uvm`` example builds a self-checking UVM test using an
external Accellera UVM source tree. It exercises factory creation, timed
operations, phasing, objections and reporting. DPI mode also checks each
observed value through ``uvm_hdl_read``.

The qualified reference library is unmodified Accellera UVM 2020.3.1,
commit ``78c06547a2a0a29b3dc9dcafae62b75b2ff61544``. Obtain that release
from Accellera before running the example. ``UVM_SOURCE_ROOT`` names its
checkout directory, containing ``src/uvm_pkg.sv`` and
``src/uvm_macros.svh``. The example does not download or modify the
selected library.

Copy ``examples/make_uvm`` from the Verilator distribution into a writable
directory. Use GNU Make and a C++20-capable toolchain with coroutine
support, as required by this timed :vlopt:`--binary` example. Configure
Verilator with that toolchain before building from a source checkout. With
an installed Verilator on ``PATH``, run:

.. code-block:: bash

   make UVM_SOURCE_ROOT=/path/to/uvm-core UVM_DPI=1

To use a built Verilator source checkout, set ``VERILATOR_ROOT`` first:

.. code-block:: bash

   export VERILATOR_ROOT=/path/to/verilator
   make UVM_SOURCE_ROOT=/path/to/uvm-core UVM_DPI=1

The eight checked operations produce ``UVM_EXAMPLE_ITEM`` records and end
with ``UVM_EXAMPLE_PASSED operations=8 dpi=1``. A value mismatch, failed
HDL read, incomplete operation count or UVM error fails the example.

Run the same example without the UVM DPI implementation:

.. code-block:: bash

   make UVM_SOURCE_ROOT=/path/to/uvm-core UVM_DPI=0

This run retains the timed value and UVM phase checks, reports
``UVM_EXAMPLE_PASSED operations=8 dpi=0``, and does not exercise HDL-access
APIs. Use DPI mode when those APIs are required.

Configuration
-------------

``UVM_DPI`` must be ``0`` or ``1``; its default is ``1``. The two modes use
separate subdirectories under ``obj_dir``. ``BUILD_JOBS`` sets a positive
number of C++ build jobs and defaults to one. ``MODEL_CFLAGS`` defaults to
``-O0`` to keep example compilation small. These settings are example build
choices, not performance recommendations. ``RUN_ARGS`` defaults to
``+UVM_NO_RELNOTES`` and accepts simulation arguments. ``VERILATOR`` may
override the selected executable. ``make clean`` removes the example's
``obj_dir``; ``make help`` prints the selection syntax without requiring a
library.

The Makefile reports a missing package, macro header or required DPI source
before compiling. Build and library paths must not contain spaces, as with
the other GNU Make examples. To switch libraries, rerun ``make`` with the
new explicit ``UVM_SOURCE_ROOT``; the build command is rerun for that tree.

The installed ``verilated_uvm_dpi.cpp`` adapter links the selected
library's unchanged common, regular-expression and command-line components
with Verilator's HDL backend. Projects reusing the example should compile
``uvm_dpi.cpp``, supply the selected library's ``src/dpi`` include
directory, and enable :vlopt:`--vpi`, as the example Makefile does. Compile
the selected ``uvm_pkg.sv`` before user SystemVerilog and add its ``src``
include directory. No-DPI builds instead define ``UVM_NO_DPI`` and omit the
adapter.

This example demonstrates source selection and the operations it checks.
Passing it does not establish complete IEEE 1800.2 compliance or support
for every UVM workload. Other library releases need separate qualification.
