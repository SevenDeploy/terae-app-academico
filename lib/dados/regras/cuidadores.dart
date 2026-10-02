/// Limite de dois cuidadores por paciente (§7.4, §23; TM07, TM10), como regra
/// pura: vale na memória (convidar e aceitar) e no contador "n/2" da TM07.
library;

import '../enums/situacao_vinculo.dart';
import '../modelos/convite_acesso.dart';
import '../modelos/vinculo_cuidador.dart';

/// O [convite] ainda pode ser usado em [agora]: não foi usado e não venceu
/// (§23: convite expirado não ativa nada).
bool conviteEmAberto(ConviteAcesso convite, DateTime agora) =>
    convite.usadoEm == null && agora.isBefore(convite.expiraEm);

/// O [vinculo] ocupa uma das duas vagas em [agora]: ativo, ou pendente com o
/// [convite] em aberto. Pendente com convite vencido não ocupa vaga — e o
/// mesmo CPF pode ser convidado de novo —, mas continua na lista até ser
/// revogado (nada muda sozinho, nada é apagado).
bool contaNoLimite({
  required VinculoCuidador vinculo,
  required ConviteAcesso convite,
  required DateTime agora,
}) => switch (vinculo.situacao) {
  SituacaoVinculo.ativo => true,
  SituacaoVinculo.pendente => conviteEmAberto(convite, agora),
  SituacaoVinculo.revogado => false,
};

/// Pendente cujo convite venceu sem ser usado (TM07: "Convite expirado").
bool conviteExpirado({
  required VinculoCuidador vinculo,
  required ConviteAcesso convite,
  required DateTime agora,
}) =>
    vinculo.situacao == SituacaoVinculo.pendente &&
    convite.usadoEm == null &&
    !agora.isBefore(convite.expiraEm);
