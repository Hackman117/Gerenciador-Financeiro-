/// Modelos do módulo de Cartões de Crédito e Compras Parceladas.
///
/// As tabelas `credit_cards`, `purchases` e `purchase_parcels` são criadas
/// por SQL bruto em [AppDatabase] e mapeadas para estes modelos simples.
library;

class CreditCard {
  const CreditCard({
    required this.id,
    required this.name,
    required this.accountId,
    required this.creditLimit,
    required this.closingDay,
    required this.dueDay,
    required this.color,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String accountId;
  final int creditLimit;
  final int closingDay;
  final int dueDay;
  final int color;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  CreditCard copyWith({
    String? name,
    String? accountId,
    int? creditLimit,
    int? closingDay,
    int? dueDay,
    int? color,
    bool? active,
  }) =>
      CreditCard(
        id: id,
        name: name ?? this.name,
        accountId: accountId ?? this.accountId,
        creditLimit: creditLimit ?? this.creditLimit,
        closingDay: closingDay ?? this.closingDay,
        dueDay: dueDay ?? this.dueDay,
        color: color ?? this.color,
        active: active ?? this.active,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
}

/// Cartão com o valor já utilizado (soma das parcelas em aberto).
class CreditCardUsage {
  const CreditCardUsage({required this.card, required this.used});

  final CreditCard card;
  final int used;

  int get available {
    final value = card.creditLimit - used;
    return value < 0 ? 0 : value;
  }

  double get ratio {
    if (card.creditLimit <= 0) return 0;
    return (used / card.creditLimit).clamp(0.0, 1.0);
  }
}

class Purchase {
  const Purchase({
    required this.id,
    required this.creditCardId,
    required this.establishment,
    required this.totalAmount,
    required this.installmentCount,
    required this.installmentAmount,
    required this.purchaseDate,
    required this.description,
    required this.paid,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.subcategoryId,
    this.deletedAt,
  });

  final String id;
  final String creditCardId;
  final String? categoryId;
  final String? subcategoryId;
  final String establishment;
  final int totalAmount;
  final int installmentCount;
  final int installmentAmount;
  final DateTime purchaseDate;
  final String description;
  final bool paid;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isCash => installmentCount <= 1;
}

class PurchaseParcel {
  const PurchaseParcel({
    required this.id,
    required this.purchaseId,
    required this.installmentNumber,
    required this.amount,
    required this.dueDate,
    required this.paid,
    required this.createdAt,
    required this.updatedAt,
    this.paidAt,
  });

  final String id;
  final String purchaseId;
  final int installmentNumber;
  final int amount;
  final DateTime dueDate;
  final bool paid;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOpen => !paid;
}
