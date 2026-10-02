import 'package:flutter/material.dart';

import '../tema/cores.dart';

/// Selo "Projeto acadêmico — UNEMAT 2026" (D1b): na TM00 e onde mais o app
/// puder ser confundido com o produto Terae.
class SeloAcademico extends StatelessWidget {
  const SeloAcademico({super.key});

  static const String texto = 'Projeto acadêmico — UNEMAT 2026';

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CoresTerae.neutro100,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: CoresTerae.neutro300),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 18, color: CoresTerae.neutro600),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CoresTerae.neutro700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
