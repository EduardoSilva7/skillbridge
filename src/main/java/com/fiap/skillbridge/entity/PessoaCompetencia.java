package com.fiap.skillbridge.entity;

import jakarta.persistence.*;

@Entity
@Table(name = "pessoa_competencia")
@IdClass(PessoaCompetenciaId.class)
public class PessoaCompetencia {
  @Id
  @Column(name="pessoa_id")
  private Long pessoaId;

  @Id
  @Column(name="competencia_id")
  private Long competenciaId;

  private int nivel;

  public Long getPessoaId() { return pessoaId; }
  public void setPessoaId(Long pessoaId) { this.pessoaId = pessoaId; }

  public Long getCompetenciaId() { return competenciaId; }
  public void setCompetenciaId(Long competenciaId) { this.competenciaId = competenciaId; }

  public int getNivel() { return nivel; }
  public void setNivel(int nivel) { this.nivel = nivel; }
}
