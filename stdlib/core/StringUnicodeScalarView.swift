//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

public func ==(
  lhs: String.UnicodeScalarView.Index,
  rhs: String.UnicodeScalarView.Index
) -> Bool {
  return lhs._position == rhs._position
}

public func <(
  lhs: String.UnicodeScalarView.Index,
  rhs: String.UnicodeScalarView.Index
) -> Bool {
  return lhs._position < rhs._position
}

extension String {
  public struct UnicodeScalarView : Sliceable, SequenceType, Reflectable {
    init(_ _core: _StringCore) {
      self._core = _core
    }

    struct _ScratchGenerator : GeneratorType {
      var core: _StringCore
      var idx: Int
      init(_ core: _StringCore, _ pos: Int) {
        self.idx = pos
        self.core = core
      }
      mutating func next() -> UTF16.CodeUnit? {
        if idx == core.endIndex {
          return .None
        }
        return self.core[idx++]
      }
    }

    public struct Index : BidirectionalIndexType, Comparable {
      public init(_ _position: Int, _ _core: _StringCore) {
        self._position = _position
        self._core = _core
      }

      public func successor() -> Index {
        var scratch = _ScratchGenerator(_core, _position)
        var decoder = UTF16()
        let (result, length) = decoder._decodeOne(&scratch)
        return Index(_position + length, _core)
      }

      public func predecessor() -> Index {
        var i = _position
        let codeUnit = _core[--i]
        if _slowPath((codeUnit >> 10) == 0b1101_11) {
          if i != 0 && (_core[i - 1] >> 10) == 0b1101_10 {
            --i
          }
        }
        return Index(i, _core)
      }

      /// The end index that for this view.
      internal var _viewStartIndex: Index {
        return Index(_core.startIndex, _core)
      }

      /// The end index that for this view.
      internal var _viewEndIndex: Index {
        return Index(_core.endIndex, _core)
      }

      var _position: Int
      var _core: _StringCore
    }

    /// The position of the first `UnicodeScalar` if the `String` is
    /// non-empty; identical to `endIndex` otherwise.
    public var startIndex: Index {
      return Index(_core.startIndex, _core)
    }

    /// The "past the end" position.
    ///
    /// `endIndex` is not a valid argument to `subscript`, and is always
    /// reachable from `startIndex` by zero or more applications of
    /// `successor()`.
    public var endIndex: Index {
      return Index(_core.endIndex, _core)
    }

    /// Access the element at `position`.
    ///
    /// Requires: `position` is a valid position in `self` and
    /// `position != endIndex`.
    public subscript(position: Index) -> UnicodeScalar {
      var scratch = _ScratchGenerator(_core, position._position)
      var decoder = UTF16()
      switch decoder.decode(&scratch) {
      case .Result(let us):
        return us
      case .EmptyInput:
        _sanityCheckFailure("can not subscript using an endIndex")
      case .Error:
        return UnicodeScalar(0xfffd)
      }
    }

    public subscript(r: Range<Index>) -> UnicodeScalarView {
      return UnicodeScalarView(
        _core[r.startIndex._position..<r.endIndex._position])
    }

    public struct Generator : GeneratorType {
      init(_ _base: _StringCore.Generator) {
        self._base = _base
      }

      public mutating func next() -> UnicodeScalar? {
        switch _decoder.decode(&self._base) {
        case .Result(let us):
          return us
        case .EmptyInput:
          return .None
        case .Error:
          return UnicodeScalar(0xfffd)
        }
      }
      var _decoder: UTF16 = UTF16()
      var _base: _StringCore.Generator
    }

    public func generate() -> Generator {
      return Generator(_core.generate())
    }

    public func getMirror() -> MirrorType {
      return _UnicodeScalarViewMirror(self)
    }

    var _core: _StringCore
  }
}

extension String {
  public init(_ view: UnicodeScalarView) {
    self = String(view._core)
  }

  public var unicodeScalars : UnicodeScalarView {
    get {
      return UnicodeScalarView(_core)
    }
    set {
      _core = newValue._core
    }
  }
}

extension String.UnicodeScalarView : ExtensibleCollectionType {
  public init() {
    self = String.UnicodeScalarView(_StringCore())
  }
  public mutating func reserveCapacity(capacity: Int) {
    _core.reserveCapacity(capacity)
  }
  public mutating func append(x: UnicodeScalar) {
    _core.append(x)
  }
  public mutating func extend<
    S : SequenceType where S.Generator.Element == UnicodeScalar
  >(seq: S) {
    _core.extend(
      _lazyConcatenate(lazy(seq).map { $0.utf16 })
    )
  }
}

extension String.UnicodeScalarView : RangeReplaceableCollectionType {

  /// Replace the given `subRange` of elements with `newValues`.
  /// Complexity: O(\ `countElements(subRange)`\ ) if `subRange.endIndex
  /// == self.endIndex` and `isEmpty(newValues)`\ , O(N) otherwise.
  public mutating func replaceRange<
    C: CollectionType where C.Generator.Element == UnicodeScalar
  >(
    subRange: Range<Index>, with newValues: C
  ) {
    _core.replaceRange(
      subRange.startIndex._position
      ..< subRange.endIndex._position,
      with:
        _lazyConcatenate(lazy(newValues).map { $0.utf16 })
    )
  }

  public mutating func insert(newElement: UnicodeScalar, atIndex i: Index) {
    Swift.insert(&self, newElement, atIndex: i)
  }
  
  public mutating func splice<
    S : CollectionType where S.Generator.Element == UnicodeScalar
  >(newValues: S, atIndex i: Index) {
    Swift.splice(&self, newValues, atIndex: i)
  }

  public mutating func removeAtIndex(i: Index) -> UnicodeScalar {
    return Swift.removeAtIndex(&self, i)
  }
  
  public mutating func removeRange(subRange: Range<Index>) {
    Swift.removeRange(&self, subRange)
  }

  public mutating func removeAll(keepCapacity: Bool = false) {
    Swift.removeAll(&self, keepCapacity: keepCapacity)
  }
}
