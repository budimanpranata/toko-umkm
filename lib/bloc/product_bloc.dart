import 'package:flutter_bloc/flutter_bloc.dart';
import '../../database_helper.dart';
import '../../model/product_model.dart';

// --- EVENTS ---
abstract class ProductEvent {
  const ProductEvent();
}

class LoadProducts extends ProductEvent {
  const LoadProducts();
}

class SearchProducts extends ProductEvent {
  final String query;
  const SearchProducts(this.query);
}

class AddProduct extends ProductEvent {
  final Product product;
  const AddProduct(this.product);
}

class UpdateProduct extends ProductEvent {
  final Product product;
  const UpdateProduct(this.product);
}

class DeleteProduct extends ProductEvent {
  final int id;
  const DeleteProduct(this.id);
}

// --- STATES ---
abstract class ProductState {
  const ProductState();
}

class ProductInitial extends ProductState {
  const ProductInitial();
}

class ProductLoading extends ProductState {
  const ProductLoading();
}

class ProductLoaded extends ProductState {
  final List<Product> products;
  final List<Product> fastMovingProducts;
  const ProductLoaded(this.products, this.fastMovingProducts);
}

class ProductError extends ProductState {
  final String errorMessage;
  const ProductError(this.errorMessage);
}

// --- BLOC ---
class ProductBloc extends Bloc<ProductEvent, ProductState> {
  ProductBloc() : super(const ProductInitial()) {
    on<LoadProducts>(_onLoadProducts);
    on<SearchProducts>(_onSearchProducts);
    on<AddProduct>(_onAddProduct);
    on<UpdateProduct>(_onUpdateProduct);
    on<DeleteProduct>(_onDeleteProduct);
  }

  Future<void> _onLoadProducts(
    LoadProducts event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductLoading());
    try {
      final productList = await DatabaseHelper.instance.readAllProducts();
      final fastMovingList =
          await DatabaseHelper.instance.getFastMovingProducts();
      emit(ProductLoaded(productList, fastMovingList));
    } catch (error) {
      emit(ProductError(error.toString()));
    }
  }

  Future<void> _onSearchProducts(
    SearchProducts event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductLoading());
    try {
      final productList = await DatabaseHelper.instance.searchProducts(
        event.query,
      );
      final fastMovingList =
          await DatabaseHelper.instance.getFastMovingProducts();
      emit(ProductLoaded(productList, fastMovingList));
    } catch (error) {
      emit(ProductError(error.toString()));
    }
  }

  Future<void> _onAddProduct(
    AddProduct event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductLoading());
    try {
      await DatabaseHelper.instance.createProduct(event.product);
      final productList = await DatabaseHelper.instance.readAllProducts();
      final fastMovingList =
          await DatabaseHelper.instance.getFastMovingProducts();
      emit(ProductLoaded(productList, fastMovingList));
    } catch (error) {
      emit(ProductError(error.toString()));
    }
  }

  Future<void> _onUpdateProduct(
    UpdateProduct event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductLoading());
    try {
      await DatabaseHelper.instance.updateProduct(event.product);
      final productList = await DatabaseHelper.instance.readAllProducts();
      final fastMovingList =
          await DatabaseHelper.instance.getFastMovingProducts();
      emit(ProductLoaded(productList, fastMovingList));
    } catch (error) {
      emit(ProductError(error.toString()));
    }
  }

  Future<void> _onDeleteProduct(
    DeleteProduct event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductLoading());
    try {
      await DatabaseHelper.instance.deleteProduct(event.id);
      final productList = await DatabaseHelper.instance.readAllProducts();
      final fastMovingList =
          await DatabaseHelper.instance.getFastMovingProducts();
      emit(ProductLoaded(productList, fastMovingList));
    } catch (error) {
      emit(ProductError(error.toString()));
    }
  }
}
