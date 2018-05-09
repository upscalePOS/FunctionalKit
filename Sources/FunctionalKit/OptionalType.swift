#if SWIFT_PACKAGE
    import Operadics
#endif
import Abstract

extension Optional: TypeConstructor {
    public typealias ParameterType = Wrapped
}

extension Optional: PureConstructible {
    public static func pure(_ value: ParameterType) -> Optional {
        return Optional(value)
    }
}

public extension Optional {
    typealias Generic<A> = Optional<A>
}

public extension Optional {
    public func fold <A> (onNone: () -> A, onSome: (Wrapped) -> A) -> A {
        switch self {
        case .none:
            return onNone()
        case .some(let value):
            return onSome(value)
        }
    }
}

public extension Optional{
    static func lift<A>(_ function: @escaping (ParameterType) -> A) -> (Optional) -> Optional<A> {
        return { $0.map(function) }
    }
    
    static func lift<A,B>(_ function: @escaping (A, B) -> ParameterType) -> (Optional<A>, Optional<B>) -> Optional {
        return { (ap1, ap2) in
            Generic.pure(f.curry(function)) <*> ap1 <*> ap2
        }
    }
    
    static func lift<A,B,C>(_ function: @escaping (A, B, C) -> ParameterType) -> (Optional<A>, Optional<B>, Optional<C>) -> Optional {
        return { (ap1, ap2, ap3) in
            Generic.pure(f.curry(function)) <*> ap1 <*> ap2 <*> ap3
        }
    }

    static func zip <A,B> (_ first: Optional<A>, _ second: Optional<B>) -> Optional<(A,B)> where ParameterType == (A,B) {
        switch (first,second) {
        case let (firstValue?, secondValue?):
            return .some((firstValue,secondValue))
        default:
            return .none
        }
    }
    
    func apply<A>(_ transform: Optional<(ParameterType) -> A>) -> Optional<A> {
        return Generic.zip(self, transform).map { value, function in function(value) }
    }
    
    static func <*> <A> (lhs: Optional<(ParameterType) -> A>, rhs: Optional) -> Optional<A> {
        return Generic.zip(lhs, rhs).map { function, value in function(value) }
    }
    
    func joined <A> () -> Optional<A> where ParameterType == Optional<A> {
        switch self {
        case let .some(value?):
            return Generic.some(value)
        default:
            return .none
        }
    }
    
    func traverse <A> (_ transform: (ParameterType) -> Array<A>) -> Array<Optional<A>> {
        switch self {
        case let value?:
            return Array.pure(Optional<A>.some) <*> transform(value)
        case .none:
            return Array.pure(Optional<A>.none)
        }
    }
    
    func traverse <A> (_ transform: (ParameterType) -> Effect<A>) -> Effect<Optional<A>> {
        switch self {
        case let value?:
            return Effect.pure(Optional<A>.some) <*> transform(value)
        case .none:
            return Effect.pure(Optional<A>.none)
        }
    }

    func traverse <A> (_ transform: (ParameterType) -> Future<A>) -> Future<Optional<A>> {
        switch self {
        case let value?:
            return Future.pure(Optional<A>.some) <*> transform(value)
        case .none:
            return Future.pure(Optional<A>.none)
        }
    }
    
    func traverse <A> (_ transform: (ParameterType) -> Optional<A>) -> Optional<Optional<A>> {
        switch self {
        case let value?:
            return Generic.pure(Optional<A>.some) <*> transform(value)
        case .none:
            return Generic.pure(Optional<A>.none)
        }
    }

    func filter(_ predicate: (ParameterType) -> Bool) -> Optional {
        return flatMap { (element) -> Optional in
            if predicate(element) {
                return .some(element)
            } else {
                return .none
            }
        }
    }
    
    func get(or getElseValue: @autoclosure () -> ParameterType) -> ParameterType {
        switch self {
        case let value?:
            return value
        case .none:
            return getElseValue()
        }
    }
    
    func toArray() -> Array<ParameterType> {
        switch self {
        case let value?:
            return [value]
        case .none:
            return []
        }
    }
    
//    func toResult<E>(getError: @autoclosure () -> E) -> Result<E,ParameterType> where E: Error {
//        return fold(
//            onNone: { Result.failure(getError()) },
//            onSome: Result.success)
//    }
    
    var isNil: Bool {
        switch self {
        case .some:
            return false
        case .none:
            return true
        }
    }
    
    func ifNotNil(_ action: (ParameterType) -> ()) {
        switch self {
        case let value?:
            action(value)
        case .none:
            break
        }
    }
}

//
//// MARK: - Definiton
//
//// sourcery: split4
//// sourcery: functor
//// sourcery: traversable
//// sourcery: monad
//// sourcery: concrete = "Optional"
//// sourcery: customMap = "fmap"
//// sourcery: customFlatMap = "bind"
//public protocol OptionalType: PureConstructible, CoproductType {
//	static func from(concrete: Concrete<ParameterType>) -> Self
//	func run() -> ParameterType?
//	func fold <T> (onNone: () -> T, onSome: (ParameterType) -> T) -> T
//}
//
//public extension OptionalType {
//	func fold<T>(onLeft: (()) -> T, onRight: (ParameterType) -> T) -> T {
//		return fold(onNone: { onLeft(()) }, onSome: onRight)
//	}
//}
//
//// MARK: - Data
//
//// sourcery: testFunctor
//// sourcery: testApplicative
//// sourcery: testMonad
//// sourcery: testConstruct = "init(x)"
//// sourcery: customMap = "fmap"
//// sourcery: customFlatMap = "bind"
//extension Optional: OptionalType {
//	public typealias ParameterType = Wrapped
//
//	public static func from(concrete: Optional<Wrapped>) -> Optional<Wrapped> {
//		return concrete
//	}
//	
//	public func run() -> Wrapped? {
//		return self
//	}
//
//    public func fold<T>(onNone: () -> T, onSome: (Wrapped) -> T) -> T {
//        switch self {
//        case .none:
//            return onNone()
//        case .some(let value):
//            return onSome(value)
//        }
//    }
//}
//
//// MARK: - Concrete
//
//public extension OptionalType {
//	typealias Concrete<T> = Optional<T>
//}
//
//// MARK: - Equatable
//
//public extension OptionalType where ParameterType: Equatable {
//	static func == (lhs: Self, rhs: Self) -> Bool {
//		return lhs.fold(
//			onNone: {
//				rhs.fold(
//					onNone: f.pure(true),
//					onSome: f.pure(false))
//		},
//			onSome: { value in
//				rhs.fold(
//					onNone: f.pure(false),
//					onSome: { value == $0 })
//		})
//	}
//}
//
//// MARK: - Functor
//
//public extension OptionalType {
//	func fmap <T> (_ transform: (ParameterType) -> T) -> Optional<T> {
//		return withoutActuallyEscaping(transform) { transform in
//			fold(
//				onNone: f.pure(Optional<T>.none),
//				onSome: transform >>> Optional<T>.some)
//		}
//	}
//    
//    static func lift<A>(_ function: @escaping (ParameterType) -> A) -> (Self) -> Optional<A> {
//        return { $0.fmap(function) }
//    }
//
//    static func lift<A,Applicative2>(_ function: @escaping (ParameterType, Applicative2.ParameterType) -> A) -> (Self, Applicative2) -> Optional<A> where Applicative2: OptionalType {
//        return { (ap1, ap2) in
//            Concrete.pure(f.curry(function)) <*> ap1 <*> ap2
//        }
//    }
//    
//    static func lift<A,Applicative2,Applicative3>(_ function: @escaping (ParameterType, Applicative2.ParameterType, Applicative3.ParameterType) -> A) -> (Self, Applicative2, Applicative3) -> Optional<A> where Applicative2: OptionalType, Applicative3: OptionalType {
//        return { ap1, ap2, ap3 in
//            Concrete.pure(f.curry(function)) <*> ap1 <*> ap2 <*> ap3
//        }
//    }
//}
//
//// MARK: - Cartesian
//
//public extension OptionalType {
//	typealias Zipped<O1,O2> = Optional<(O1.ParameterType,O2.ParameterType)> where O1: OptionalType, O2: OptionalType
//
//    static func zip <O1,O2> (_ first: O1, _ second: O2) -> Zipped<O1,O2> where O1: OptionalType, O2: OptionalType, ParameterType == (O1.ParameterType, O2.ParameterType) {
//        return first.fold(
//            onNone: f.pure(Zipped<O1,O2>.none),
//            onSome: { value in
//                second.fold(
//                    onNone: f.pure(Zipped<O1,O2>.none),
//                    onSome: { Zipped<O1,O2>.some((value,$0)) })
//        })
//    }
//}
//
//// MARK: - Applicative
//
//public extension OptionalType {
//	static func pure(_ value: ParameterType) -> Optional<ParameterType> {
//		return Optional<ParameterType>.init(value)
//	}
//
//    func apply<O,T>(_ transform: O) -> Optional<T> where O: OptionalType, O.ParameterType == (ParameterType) -> T {
//        return Optional.zip(self, transform).map { value, function in function(value) }
//    }
//
//    static func <*> <O,T> (lhs: O, rhs: Self) -> Optional<T> where O: OptionalType, O.ParameterType == (ParameterType) -> T {
//        return Optional.zip(lhs, rhs).map { function, value in function(value) }
//    }
//}
//
//// MARK: - Traversable
//
//public extension OptionalType {
//	typealias Traversed<Applicative> = Optional<Applicative.ParameterType> where Applicative: TypeConstructor
//
//    func traverse<Applicative>(_ transform: (ParameterType) -> Applicative) -> [Traversed<Applicative>] where Applicative: ArrayType {
//        typealias Returned = [Traversed<Applicative>]
//
//        return fold(
//            onNone: { () -> Returned in
//                Returned.pure(Traversed<Applicative>.none)
//        },
//            onSome: { (value) -> Returned in
//                Applicative.Concrete.pure(Traversed<Applicative>.some) <*> transform(value)
//        })
//    }
//
//	func traverse<Applicative>(_ transform: (ParameterType) -> Applicative) -> Future<Traversed<Applicative>> where Applicative: FutureType {
//		typealias Returned = Future<Traversed<Applicative>>
//
//		return fold(
//			onNone: { () -> Returned in
//				Returned.pure(Traversed<Applicative>.none)
//		},
//			onSome: { (value) -> Returned in
//				Applicative.Concrete.pure(Traversed<Applicative>.some) <*> transform(value)
//		})
//	}
//
//	func traverse<Applicative>(_ transform: (ParameterType) -> Applicative) -> Effect<Traversed<Applicative>> where Applicative: EffectType {
//		typealias Returned = Effect<Traversed<Applicative>>
//
//		return fold(
//			onNone: { () -> Returned in
//				Returned.pure(Traversed<Applicative>.none)
//		},
//			onSome: { (value) -> Returned in
//				Applicative.Concrete.pure(Traversed<Applicative>.some) <*> transform(value)
//		})
//	}
//
//	func traverse<Applicative>(_ transform: (ParameterType) -> Applicative) -> Optional<Traversed<Applicative>> where Applicative: OptionalType {
//		typealias Returned = Optional<Traversed<Applicative>>
//
//		return fold(
//			onNone: { () -> Returned in
//				Returned.pure(Traversed<Applicative>.none)
//		},
//			onSome: { (value) -> Returned in
//				Applicative.Concrete.pure(Traversed<Applicative>.some) <*> transform(value)
//		})
//	}
//
//	func traverse<Applicative>(_ transform: (ParameterType) -> Applicative) -> Reader<Applicative.EnvironmentType,Traversed<Applicative>> where Applicative: ReaderType {
//		typealias Returned = Reader<Applicative.EnvironmentType,Traversed<Applicative>>
//
//		return fold(
//			onNone: { () -> Returned in
//				Returned.pure(Traversed<Applicative>.none)
//		},
//			onSome: { (value) -> Returned in
//				Applicative.Concrete.pure(Traversed<Applicative>.some) <*> transform(value)
//		})
//	}
//
//	func traverse<Applicative>(_ transform: (ParameterType) -> Applicative) -> Result<Applicative.ErrorType,Traversed<Applicative>> where Applicative: ResultType {
//		typealias Returned = Result<Applicative.ErrorType,Traversed<Applicative>>
//
//		return fold(
//			onNone: { () -> Returned in
//				Returned.pure(Traversed<Applicative>.none)
//		},
//			onSome: { (value) -> Returned in
//				Applicative.Concrete.pure(Traversed<Applicative>.some) <*> transform(value)
//		})
//	}
//
//    func traverse<Applicative>(_ transform: (ParameterType) -> Applicative) -> State<Applicative.StateParameterType,Traversed<Applicative>> where Applicative: StateType {
//        typealias Returned = State<Applicative.StateParameterType,Traversed<Applicative>>
//        
//        return fold(
//            onNone: { () -> Returned in
//                Returned.pure(Traversed<Applicative>.none)
//        },
//            onSome: { (value) -> Returned in
//                Applicative.Concrete.pure(Traversed<Applicative>.some) <*> transform(value)
//        })
//    }
//
//	func traverse<Applicative>(_ transform: (ParameterType) -> Applicative) -> Writer<Applicative.LogType,Traversed<Applicative>> where Applicative: WriterType {
//		typealias Returned = Writer<Applicative.LogType,Traversed<Applicative>>
//
//		return fold(
//			onNone: { () -> Returned in
//				Returned.pure(Traversed<Applicative>.none)
//		},
//			onSome: { (value) -> Returned in
//				Applicative.Concrete.pure(Traversed<Applicative>.some) <*> transform(value)
//		})
//	}
//}
//
//// MARK: - Monad
//
//public extension OptionalType where ParameterType: OptionalType {
//	func joined() -> Optional<ParameterType.ParameterType> {
//		return fold(
//			onNone: f.pure(Optional<ParameterType.ParameterType>.none),
//			onSome: { value in
//				value.fold(
//					onNone: f.pure(Optional<ParameterType.ParameterType>.none),
//					onSome: Optional<ParameterType.ParameterType>.some)
//		})
//	}
//}
//
//public extension OptionalType {
//	func bind<O>(_ transform: (ParameterType) -> O) -> Optional<O.ParameterType> where O: OptionalType {
//		return fmap(transform).joined()
//	}
//}
//
//// MARK: - Utility
//
//public extension OptionalType {
//    func filter(_ predicate: (ParameterType) -> Bool) -> Optional<ParameterType> {
//        return bind { (element) -> Optional<ParameterType> in
//            if predicate(element) {
//                return .some(element)
//            } else {
//                return .none
//            }
//        }
//    }
//
//    func get(or getElseValue: @autoclosure () -> ParameterType) -> ParameterType {
//        return fold(
//            onNone: getElseValue,
//            onSome: f.identity)
//    }
//
//    func toArray() -> Array<ParameterType> {
//        return fold(
//            onNone: f.pure([]),
//            onSome: { [$0] })
//    }
//
//    func toResult<E>(getError: @autoclosure () -> E) -> Result<E,ParameterType> where E: Error {
//        return fold(
//            onNone: { Result.failure(getError()) },
//            onSome: Result.success)
//    }
//
//    var isNil: Bool {
//        return fold(
//            onNone: f.pure(true),
//            onSome: f.pure(false))
//    }
//
//
//    func ifNotNil(_ action: (ParameterType) -> ()) {
//        _ = fold(
//            onNone: f.ignore,
//            onSome: action)
//    }
//}
