import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/util/keyword_validator.dart';
import '../../domain/entities/country.dart';
import '../../domain/usecases/get_all_countries_usecase.dart';
import '../../domain/usecases/search_countries_usecase.dart';

part 'country_event.dart';
part 'country_state.dart';

const String SERVER_FAILURE_MESSAGE = 'Server Failure';
const String CACHE_FAILURE_MESSAGE = 'Cache Failure';
const String INVALIDA_INPUT_FAILURE_MESSAGE = 'Failure';

class CountryBloc extends Bloc<CountryEvent, CountryState> {
  final GetAllCountriesUseCase allCountries;
  final SearchCountriesUseCase searchCountries;
  final KeywordValidator validator;

  CountryBloc({
    @required GetAllCountriesUseCase allCountriesUseCase,
    @required SearchCountriesUseCase searchCountriesUseCase,
    @required this.validator
  })  : assert(allCountriesUseCase != null), 
        assert(searchCountriesUseCase != null), 
        assert(validator != null),
        allCountries = allCountriesUseCase,
        searchCountries = searchCountriesUseCase;

  @override
  CountryState get initialState => Empty();

  @override
  Stream<CountryState> mapEventToState(
    CountryEvent event,
  ) async* {
    if (event is GetCountrySearchResult) {
      final inputEither = validator.validateSearchKeyword(event.keyword);
      yield* inputEither.fold(
        (failure) async* {
          yield Error(message: INVALIDA_INPUT_FAILURE_MESSAGE);
        },
        (keyword) async* {
          yield Loading();
          if (keyword.isEmpty) {
            final failureOrCountries = await allCountries(NoParams());
            yield* _eitherAllLoadedOrErrorState(failureOrCountries);
          } else {
            final failureOrCountries = await searchCountries(SearchParams(keyword));
            yield* _eitherMatchingLoadedOrErrorState(failureOrCountries);
          }
        },
      );
    }
  }

  Stream<CountryState> _eitherAllLoadedOrErrorState(
    Either<Failure, List<Country>> failureOrCountries,
  ) async* {
    yield failureOrCountries.fold(
      (failure) => Error(message: _mapFailureToMessage(failure)), 
      (countries) => AllLoaded(countries: countries)
    );
  }

  Stream<CountryState> _eitherMatchingLoadedOrErrorState(
    Either<Failure, List<Country>> failureOrCountries,
  ) async* {
    yield failureOrCountries.fold(
      (failure) => Error(message: _mapFailureToMessage(failure)), 
      (countries) => MatchingLoaded(countries: countries)
    );
  }

  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ServerFailure:
        return SERVER_FAILURE_MESSAGE;
      case CacheFailure:
        return CACHE_FAILURE_MESSAGE;
      default:
        return 'Unexpected error';
    }
  }
}