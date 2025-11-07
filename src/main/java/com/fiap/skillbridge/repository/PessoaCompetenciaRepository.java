package com.fiap.skillbridge.repository;
import com.fiap.skillbridge.entity.PessoaCompetencia;
import com.fiap.skillbridge.entity.PessoaCompetenciaId;
import org.springframework.data.jpa.repository.JpaRepository;
public interface PessoaCompetenciaRepository extends JpaRepository<PessoaCompetencia, PessoaCompetenciaId> {}
