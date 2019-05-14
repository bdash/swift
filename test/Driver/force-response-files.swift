// Ensure that -driver-force-response-files works.


// RUN: %swiftc_driver -driver-force-response-files -typecheck %S/../Inputs/empty.swift -### 2>&1 | %FileCheck %s
// RUN: %swiftc_driver -enable-batch-mode -driver-force-response-files -typecheck %S/../Inputs/empty.swift -### 2>&1 | %FileCheck %s
// CHECK: @
// CHECK: .resp
