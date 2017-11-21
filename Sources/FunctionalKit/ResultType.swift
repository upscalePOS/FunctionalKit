import Abstract

// MARK: - Definiton

public protocol ResultType: TypeConstructor, CoproductType {
	associatedtype ErrorType: Error

	func run() throws -> ParameterType
	func fold <A> (onSuccess: @escaping (ParameterType) -> A, onFailure: @escaping (ErrorType) -> A) -> A
}

extension ResultType {
	public func fold<U>(onLeft: @escaping (ErrorType) -> U, onRight: @escaping (ParameterType) -> U) -> U {
		return fold(onSuccess: onRight, onFailure: onLeft)
	}
}

// MARK: - Data

public enum Result<E,T>: ResultType where E: Error {
	public typealias ErrorType = E
	public typealias ParameterType = T

	case success(T)
	case failure(E)

	public init(success: ParameterType) {
		self = .success(success)
	}

	public init(failure: ErrorType) {
		self = .failure(failure)
	}

	public func run() throws -> T {
		switch self {
		case .success(let value):
			return value
		case .failure(let error):
			throw error
		}
	}

	public func fold<A>(onSuccess: @escaping (T) -> A, onFailure: @escaping (E) -> A) -> A {
		switch self {
		case .success(let value):
			return onSuccess(value)
		case .failure(let error):
			return onFailure(error)
		}
	}
}

// MARK: - Concrete

extension ResultType {
	public typealias Concrete = Result<ErrorType,ParameterType>
}

// MARK: - Equatable

extension ResultType where ErrorType: Equatable, ParameterType: Equatable {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.fold(
			onSuccess: { value in
				rhs.fold(
					onSuccess: { value == $0 },
					onFailure: { _ in false })
		},
			onFailure: { error in
				rhs.fold(
					onSuccess: { _ in false },
					onFailure: { error == $0 })
		})
	}
}

// MARK: - Functor

extension ResultType {
	public func map <A> (_ transform: @escaping (ParameterType) -> A) -> Result<ErrorType,A> {
		return fold(
			onSuccess: transform..Result.success,
			onFailure: Result.failure)
	}

	public func mapError <A> (_ transform: @escaping (ErrorType) -> A) -> Result<A,ParameterType> {
		return fold(
			onSuccess: Result.success,
			onFailure: transform..Result.failure)
	}
}

// MARK: - Cartesian

extension ResultType {
	public typealias Zipped<R1,R2> = Result<InclusiveError<R1.ErrorType,R2.ErrorType>,(R1.ParameterType,R2.ParameterType)> where R1: ResultType, R2: ResultType

	public static func zip<R1,R2>(_ first: R1, _ second: R2) -> Zipped<R1,R2> where R1: ResultType, R2: ResultType, ParameterType == (R1.ParameterType,R2.ParameterType), ErrorType == InclusiveError<R1.ErrorType,R2.ErrorType> {
		return first.fold(
			onSuccess: { firstValue in
				second.fold(
					onSuccess: { secondValue in
						Zipped<R1,R2>.success((firstValue,secondValue))
				},
					onFailure: { secondError in
						Zipped<R1,R2>.failure(InclusiveError.right(secondError))
				})
		},
			onFailure: { firstError in
				second.fold(
					onSuccess: { _ in
						Zipped<R1,R2>.failure(InclusiveError.left(firstError))
				},
					onFailure: { secondError in
						Zipped<R1,R2>.failure(InclusiveError.center(firstError, secondError))
				})
		})
	}
}

// MARK: - Applicative

extension ResultType {
	public static func pure(_ value: ParameterType) -> Result<ErrorType,ParameterType> {
		return Result<ErrorType,ParameterType>.success(value)
	}

	public func apply<R,T>(_ transform: R) -> Result<ErrorType,T> where R: ResultType, R.ErrorType == ErrorType, R.ParameterType == (ParameterType) -> T {
		return Result.zip(self, transform)
			.map { value, function in function(value) }
			.mapError { $0.left }
	}

	public static func <*> <R,T> (lhs: R, rhs: Self) -> Result<ErrorType,T> where R: ResultType, R.ErrorType == ErrorType, R.ParameterType == (ParameterType) -> T {
		return Result.zip(lhs, rhs)
			.map { function, value in function(value) }
			.mapError { $0.left }
	}
}

extension ResultType where ErrorType: Semigroup {
	public func applyMerge<R,T>(_ transform: R) -> Result<ErrorType,T> where R: ResultType, R.ErrorType == ErrorType, R.ParameterType == (ParameterType) -> T {
		return Result.zip(self, transform)
			.map { value, function in function(value) }
			.mapError { $0.merged() }
	}

	public static func <*> <R,T> (lhs: R, rhs: Self) -> Result<ErrorType,T> where R: ResultType, R.ErrorType == ErrorType, R.ParameterType == (ParameterType) -> T {
		return Result.zip(lhs, rhs)
			.map { function, value in function(value) }
			.mapError { $0.merged() }
	}
}

// MARK: - Traversable

extension ResultType {
	public typealias Traversed<A> = Result<ErrorType,A.ParameterType> where A: TypeConstructor

	public func traverse<R>(_ transform: @escaping (ParameterType) -> R) -> Result<R.ErrorType,Traversed<R>> where R: ResultType {
		typealias Returned = Result<R.ErrorType,Traversed<R>>

		return fold(
			onSuccess: { (value) -> Returned in
				transform(value).map(Traversed<R>.success)
		},
			onFailure: { (error) -> Returned in
				Returned.pure(Traversed<R>.failure(error))
		})
	}

	public func traverse<O>(_ transform: @escaping (ParameterType) -> O) -> Optional<Traversed<O>> where O: OptionalType {
		typealias Returned = Optional<Traversed<O>>

		return fold(
			onSuccess: { (value) -> Returned in
				transform(value).map(Traversed<O>.success)
		},
			onFailure: { (error) -> Returned in
				Returned.pure(Traversed<O>.failure(error))
		})
	}
}

// MARK: - Monad

extension ResultType where ParameterType: ResultType, ParameterType.ErrorType == ErrorType {
	public var joined: Result<ErrorType,ParameterType.ParameterType> {
		return fold(
			onSuccess: { subresult in
				subresult.fold(
					onSuccess: { value in Result.success(value) },
					onFailure: { error in Result.failure(error) })
		},
			onFailure: { error in
				Result.failure(error)
		})
	}
}

extension ResultType {
	public func flatMap<R>(_ transform: @escaping (ParameterType) -> R) -> Result<ErrorType,R.ParameterType> where R: ResultType, R.ErrorType == ErrorType {
		return map(transform).joined
	}
}