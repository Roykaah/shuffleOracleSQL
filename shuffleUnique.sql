FUNCTION f_shuffle_unique(p_owner IN VARCHAR2,
                          p_table_name IN VARCHAR2,
                          p_column_name IN VARCHAR2,
                          p_constraint IN VARCHAR2 DEFAULT NULL)
RETURN CLOB
IS
    /*
    *   Essa procedure realiza o embaralhamento de todas as rows de uma coluna
    *   ou de um grupo de colunas de uma unique constraint.
    */
    v_erro VARCHAR2(4000);
    v_cod_coluna NUMBER;
    v_iterador NUMBER := 1;
    v_sets_template VARCHAR2(4000);
    v_records_template VARCHAR2(4000);
    v_records VARCHAR2(4000);
    v_types_template VARCHAR2(4000);
    v_types VARCHAR2(4000);
    v_for_template VARCHAR2(4000);
    v_for VARCHAR2(4000);
    v_valores VARCHAR2(4000);
    v_colunas VARCHAR2(4000);
    v_deletes VARCHAR2(4000) := '';
    v_plsql_template VARCHAR2(4000) := '
        DECLARE
            TYPE t_rowid IS TABLE OF rowid;
            TYPE t_valores_coluna IS TABLE OF #OWNER#."#TABLE_NAME#"."#COLUMN_NAME#"%type;
            TYPE t_combinacao IS RECORD(coluna1 rowid,
                                        coluna2 rowid,
                                        #RECORD#);
            TYPE t_mapeamento IS TABLE OF t_combinacao;
            #TYPES#
            v_rowids t_rowid := t_rowid();
            v_mapeamento t_mapeamento := t_mapeamento();
            v_combinacao t_combinacao;
            v_idx_metade number;
            v_quantidade_rows NUMBER;
        BEGIN
            SELECT rowid,#COLUNAS# BULK COLLECT INTO v_rowids,#V_VALORES#
            FROM #OWNER#."#TABLE_NAME#"
            WHERE "#COLUMN_NAME#" IS NOT NULL
            ORDER BY dbms_random.random;
            v_idx_metade := FLOOR(v_rowids.count / 2);
            FOR x IN v_rowids.first .. v_idx_metade LOOP
                v_combinacao.coluna1 := v_rowids(x);
                v_combinacao.coluna2 := v_rowids(x + v_idx_metade);
                #V_FOR#
                v_mapeamento.extend;
                v_mapeamento(v_mapeamento.last) := v_combinacao;
            END LOOP;
            #DELETES#
            FORALL x IN v_mapeamento.first .. v_mapeamento.last
                UPDATE #OWNER#."#TABLE_NAME#"
                    SET #SET#
                        WHERE rowid = v_mapeamento(x).coluna1
                        OR rowid = v_mapeamento(x).coluna2;
            COMMIT;
            v_mapeamento.delete;
        END;';
    v_plsql CLOB := '';
BEGIN
    /*
    * The following mess is a logic to replace all the #keys# with other values to make it work
    */
    -- o v_records_template é onde se declaram as colunas da collection t_combinacao, a qual receberá os dados da tabela em memória
    v_records_template := 'valor'||((v_iterador*2) - 1)||' #OWNER#."#TABLE_NAME#"."#COLUMN_NAME#"%type,
                           valor'||(v_iterador*2)||' #OWNER#."#TABLE_NAME#"."#COLUMN_NAME#"%type';

    -- o v_types_template é onde são declaradas as collections que receberão os dados da tabela em memória
    v_types_template := 'TYPE t_valores_coluna'||v_iterador||' IS TABLE OF #OWNER#."#TABLE_NAME#"."#COLUMN_NAME#"%type;
                         v_valores'||v_iterador||' t_valores_coluna'||v_iterador||' := t_valores_coluna'||v_iterador||'();';

    -- o v_for_template ajuda a indexar os valores das collections de valores em apenas uma collection (v_combinacao)
    v_for_template := 'v_combinacao.valor'||((v_iterador*2) - 1)||' := v_valores'||v_iterador||'(x);
                       v_combinacao.valor'||(v_iterador*2) ||' := v_valores'||v_iterador||'(x + v_idx_metade);';

    -- o v_sets_template faz parte do código que irá trocar os valores da coluna através do update set...
    v_sets_template := '"#COLUMN_NAME#" =
                        CASE
                            WHEN rowid = v_mapeamento(x).coluna1 THEN v_mapeamento(x).valor'||(v_iterador*2)||'
                            WHEN rowid = v_mapeamento(x).coluna2 THEN v_mapeamento(x).valor'||((v_iterador*2) - 1)||
                       ' END';

    v_for := v_for_template;
    v_valores := 'v_valores'||v_iterador;
    v_colunas := p_column_name;

    v_records := v_records_template;
    v_records := REPLACE(v_records,'#COLUMN_NAME#', p_column_name);

    v_types := v_types_template;
    v_types := REPLACE(v_types, '#COLUMN_NAME#', p_column_name);

    v_plsql := v_sets_template;
    v_plsql := REPLACE(v_plsql, '#COLUMN_NAME#', p_column_name);

    v_deletes := 'v_rowids.delete;
                  v_valores'||v_iterador||'.delete;';

    -- Monta as partes do comando pl/sql a partir das colunas da constraint unique
    FOR cur_sets IN (SELECT column_name
                       FROM all_cons_columns
                       WHERE owner = p_owner
                         AND constraint_name = p_constraint
                         AND table_name = p_table_name
                         AND column_name <> p_column_name) LOOP

        v_iterador := v_iterador +1;

        v_for:= v_for|| 'v_combinacao.valor'||((v_iterador*2)-1)||':= v_valores'||v_iterador||'(x);
                       v_combinacao.valor'||(v_iterador*2) ||' := v_valores'||v_iterador||'(x + v_idx_metade);';

        v_valores := v_valores || ',v_valores'||v_iterador;
        v_colunas := v_colunas || ',' ||cur_sets.column_name;

        v_types := v_types||'TYPE t_valores_coluna'||v_iterador||' IS TABLE OF #OWNER#."#TABLE_NAME#"."#COLUMN_NAME#"%type;'
                    ||' v_valores'||v_iterador||' t_valores_coluna'||v_iterador||' := t_valores_coluna'||v_iterador||'();';
        v_types := REPLACE(v_types, '#COLUMN_NAME#', cur_sets.column_name);

        v_records := v_records||','||'valor'||((v_iterador*2)-1)||' #OWNER#."#TABLE_NAME#"."#COLUMN_NAME#"%type,
                           valor'||(v_iterador*2)||' #OWNER#."#TABLE_NAME#"."#COLUMN_NAME#"%type';
        v_records := REPLACE(v_records, '#COLUMN_NAME#', cur_sets.column_name);

        v_plsql := v_plsql||','||'"#COLUMN_NAME#" =
                        CASE
                            WHEN rowid = v_mapeamento(x).coluna2 THEN v_mapeamento(x).valor'||((v_iterador*2)- 1)||'
                            WHEN rowid = v_mapeamento(x).coluna1 THEN v_mapeamento(x).valor'||(v_iterador*2)||
                       ' END';
        v_plsql := REPLACE(v_plsql, '#COLUMN_NAME#', cur_sets.column_name);

        v_deletes := v_deletes || 'v_valores'||v_iterador||'.delete; ';
    END LOOP;
    -- Substitui as partes no template
    v_plsql := REPLACE(v_plsql_template, '#SET#', v_plsql);
    v_plsql := REPLACE(v_plsql,'#RECORD#',v_records);
    v_plsql := REPLACE(v_plsql,'#V_FOR#',v_for);
    v_plsql := REPLACE(v_plsql,'#COLUNAS#',v_colunas);
    v_plsql := REPLACE(v_plsql,'#V_VALORES#',v_valores);
    v_plsql := REPLACE(v_plsql,'#TYPES#',v_types);
    v_plsql := REPLACE(v_plsql,'#DELETES#',v_deletes);
    v_plsql := REPLACE(v_plsql, '#OWNER#', p_owner);
    v_plsql := REPLACE(v_plsql, '#TABLE_NAME#', p_table_name);
    v_plsql := REPLACE(v_plsql, '#COLUMN_NAME#', p_column_name);

    RETURN v_plsql;
END;