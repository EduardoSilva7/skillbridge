package com.fiap.skillbridge.entity;

import java.io.Serializable;
import java.util.Objects;

public class PessoaCompetenciaId implements Serializable {
  private Long pessoaId;
  private Long competenciaId;

  public PessoaCompetenciaId() {}
  public PessoaCompetenciaId(Long pessoaId, Long competenciaId) {
    this.pessoaId = pessoaId;
    this.competenciaId = competenciaId;
  }
  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (o == null || getClass() != o.getClass()) return false;
    PessoaCompetenciaId that = (PessoaCompetenciaId) o;
    return java.util.Objects.equals(pessoaId, that.pessoaId) && java.util.Objects.equals(competenciaId, that.competenciaId);
  }
  @Override
  public int hashCode() {
    return java.util.Objects.hash(pessoaId, competenciaId);
  }
}
