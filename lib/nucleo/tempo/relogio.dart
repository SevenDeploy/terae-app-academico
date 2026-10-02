/// "Agora" injetável e horário da clínica (D7; §23 "Datas e horas são gravadas
/// com fuso e exibidas no horário da clínica").
///
/// Regras: nenhum código lê `DateTime.now()` fora de [RelogioSistema]; todo
/// instante trafega em UTC (`isUtc`); a exibição passa pelos formatadores
/// abaixo, que convertem para o fuso fixo da clínica (−04:00, Cuiabá, sem
/// horário de verão). Os formatadores são pt-BR escritos à mão para não
/// depender de `initializeDateFormatting` em teste.
library;

import 'data_civil.dart';

/// Deslocamento fixo do fuso da clínica em relação a UTC (America/Cuiaba).
const Duration deslocamentoClinica = Duration(hours: -4);

/// O mesmo deslocamento escrito como no ISO 8601.
const String fusoClinicaIso = '-04:00';

/// Fonte do "agora". Telas e controladores recebem por provider
/// (`context.read<Relogio>()`); repositórios, por construtor.
abstract interface class Relogio {
  /// Instante atual, sempre em UTC.
  DateTime agora();
}

/// Relógio do aparelho — o único lugar do app que lê `DateTime.now()`.
class RelogioSistema implements Relogio {
  const RelogioSistema();

  @override
  DateTime agora() => DateTime.now().toUtc();
}

/// Relógio parado, para teste e demonstração determinísticos.
class RelogioFixo implements Relogio {
  RelogioFixo(DateTime instante) : _instante = instante.toUtc();

  DateTime _instante;

  @override
  DateTime agora() => _instante;

  /// Faz o tempo andar (ex.: a TM04 volta sozinha em 3 s).
  void avancar(Duration duracao) => _instante = _instante.add(duracao);

  /// Põe o relógio num instante qualquer.
  void definir(DateTime instante) => _instante = instante.toUtc();
}

/// Instante (UTC) correspondente a uma hora de parede da clínica:
/// `instanteNaClinica(2026, 10, 7, 14)` = 7/10/2026 14:00 em Cuiabá = 18:00Z.
DateTime instanteNaClinica(
  int ano,
  int mes,
  int dia, [
  int hora = 0,
  int minuto = 0,
]) => DateTime.utc(ano, mes, dia, hora, minuto).subtract(deslocamentoClinica);

/// O instante lido no relógio de parede da clínica. Os campos (`year`, `hour`…)
/// do resultado são os da clínica; ele NÃO é um instante válido — serve só
/// para ler campos e formatar.
DateTime naClinica(DateTime instante) =>
    instante.toUtc().add(deslocamentoClinica);

const List<String> _diasDaSemana = [
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
];

const List<String> _meses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

String _dois(int n) => n.toString().padLeft(2, '0');

String _maiuscula(String texto) =>
    texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);

/// Nome do dia da semana em minúsculas (`DateTime.monday` = 1 … `sunday` = 7).
String nomeDiaDaSemana(int diaDaSemana) => _diasDaSemana[diaDaSemana - 1];

/// Nome do mês em minúsculas (1 = janeiro).
String nomeDoMes(int mes) => _meses[mes - 1];

/// `14:00` no horário da clínica.
String formatarHora(DateTime instante) {
  final c = naClinica(instante);
  return '${_dois(c.hour)}:${_dois(c.minute)}';
}

/// `07/10/2026` no horário da clínica.
String formatarData(DateTime instante) =>
    formatarDataCivil(DataCivil.doInstante(instante));

/// `07/10/2026 às 14:00` no horário da clínica.
String formatarDataHora(DateTime instante) =>
    '${formatarData(instante)} às ${formatarHora(instante)}';

/// `Quarta-feira, 7 de outubro` no horário da clínica.
String formatarDiaPorExtenso(DateTime instante) =>
    formatarDataCivilPorExtenso(DataCivil.doInstante(instante));

/// `14/03/2010`.
String formatarDataCivil(DataCivil data) =>
    '${_dois(data.dia)}/${_dois(data.mes)}/${data.ano}';

/// `Quarta-feira, 7 de outubro`.
String formatarDataCivilPorExtenso(DataCivil data) => _maiuscula(
  '${nomeDiaDaSemana(data.diaDaSemana)}, ${data.dia} de ${nomeDoMes(data.mes)}',
);

/// Distância em dias civis, em linguagem simples (RNFM01): `hoje`, `amanhã`,
/// `em 5 dias`, `ontem`, `há 3 dias`.
String descricaoRelativa(DataCivil alvo, {required DataCivil hoje}) {
  final dias = hoje.diasAte(alvo);
  if (dias == 0) return 'hoje';
  if (dias == 1) return 'amanhã';
  if (dias == -1) return 'ontem';
  return dias > 1 ? 'em $dias dias' : 'há ${-dias} dias';
}
