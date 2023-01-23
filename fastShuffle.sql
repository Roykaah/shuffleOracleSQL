FUNCTION f_fast_shuffle(p_owner IN VARCHAR2, p_table_name IN VARCHAR2,
                        p_column_name IN VARCHAR2)
RETURN CLOB
IS
    /*
        Essa procedure realiza o embaralhamento de todas as rows de uma coluna.
    */
    v_erro VARCHAR2(4000);
    v_cod_coluna NUMBER;
    v_plsql_template VARCHAR2(4000) := '
        DECLARE
            TYPE t_rowid IS TABLE OF rowid;
            TYPE t_valores_coluna IS TABLE OF #OWNER#."#TABLE_NAME#"."#COLUMN_NAME#"%type;
            TYPE t_combinacao IS RECORD(indicador rowid,
                                        valor #OWNER#."#TABLE_NAME#"."#COLUMN_NAME#"%type);
            TYPE t_mapeamento IS TABLE OF t_combinacao;

            v_rowids t_rowid := t_rowid();
            v_valores t_valores_coluna := t_valores_coluna();
            v_mapeamento t_mapeamento := t_mapeamento();
            v_combinacao t_combinacao;
            v_idx_metade PLS_INTEGER;
            v_comando_testa_vazio VARCHAR2(4000);
            v_se_existe_rows number;
        BEGIN
            SELECT MAX(1) into v_se_existe_rows FROM #OWNER#."#TABLE_NAME#" WHERE "#COLUMN_NAME#" IS NOT NULL AND ROWNUM <= 1;
            if v_se_existe_rows = 1 THEN

                SELECT rowid BULK COLLECT INTO v_rowids
                FROM #OWNER#."#TABLE_NAME#"
                WHERE "#COLUMN_NAME#" IS NOT NULL;

                SELECT "#COLUMN_NAME#" BULK COLLECT INTO v_valores
                FROM #OWNER#."#TABLE_NAME#"
                WHERE "#COLUMN_NAME#" IS NOT NULL
                ORDER BY dbms_random.random;

                FOR x IN v_rowids.first .. v_rowids.count LOOP
                    v_combinacao.indicador := v_rowids(x);
                    v_combinacao.valor := v_valores(x);
                    v_mapeamento.extend;
                    v_mapeamento(v_mapeamento.last) := v_combinacao;
                END LOOP;
                v_rowids.delete;
                v_valores.delete;

                FORALL x IN v_mapeamento.first .. v_mapeamento.last
                    UPDATE #OWNER#."#TABLE_NAME#"
                        SET "#COLUMN_NAME#" =v_mapeamento(x).valor
                        WHERE rowid = v_mapeamento(x).indicador;
                COMMIT;
                v_mapeamento.delete;
            END IF;
        END;';
    v_plsql CLOB := '';
BEGIN
    v_plsql := REPLACE(v_plsql_template, '#OWNER#', p_owner);
    v_plsql := REPLACE(v_plsql, '#TABLE_NAME#', p_table_name);
    v_plsql := REPLACE(v_plsql, '#COLUMN_NAME#', p_column_name);
    RETURN v_plsql;
END;
