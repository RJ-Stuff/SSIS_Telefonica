CREATE TABLE #MASTER_SERVICIO_DELTA
(
COD_SISTEMA tinyint,
COD_CLIENTE int,
COD_CUENTA varchar(10),
COD_SERVICIO varchar(12),
COD_ESTADO tinyint,
CONSTRAINT [PK_MASTER_SERVICIO_DELTA_TEMP] PRIMARY KEY CLUSTERED (COD_SISTEMA ASC, COD_CLIENTE ASC, COD_CUENTA ASC, COD_SERVICIO ASC)
)

BULK INSERT #MASTER_SERVICIO_DELTA
FROM CONCAT ('D:\MUESTRA\MASTER_SERVICIO_DELTA_' , RIGHT('0' + RTRIM(DAY(GETDATE())), 2) , RIGHT('0' + RTRIM(MONTH(GETDATE())), 2) + '.txt')
WITH ( FIELDTERMINATOR = '|', ROWTERMINATOR = '\n' );

--select * from #MASTER_SERVICIO_DELTA where COD_SISTEMA = 1 and COD_CLIENTE = 734956501

MERGE MASTER_SERVICIO t
USING #MASTER_SERVICIO_DELTA s
ON t.COD_SISTEMA = s.COD_SISTEMA and t.COD_CLIENTE = s.COD_CLIENTE and t.COD_CUENTA = s.COD_CUENTA and s.COD_SERVICIO = t.COD_SERVICIO
WHEN MATCHED THEN UPDATE SET t.COD_ESTADO = s.COD_ESTADO;

DROP TABLE #MASTER_SERVICIO_DELTA

--Actualizacion DetalleMoroso
create table #source1(cod_luna int, telefono varchar(300),INDEX SourceCod NONCLUSTERED (cod_Luna ASC, telefono ASC))
insert #source1
select l.COD_LUNA, telefono
FROM Moroso L
INNER JOIN MASTER_CLIENTE CL ON L.COD_LUNA = CL.COD_LUNA --and COD_CLIENTE <>'100000000'
INNER JOIN CORE_SISTEMA S ON S.COD_SISTEMA = CL.COD_SISTEMA
INNER JOIN MASTER_CUENTA Q ON Q.COD_SISTEMA = CL.COD_SISTEMA AND Q.COD_CLIENTE = CL.COD_CLIENTE
INNER JOIN MASTER_SERVICIO Z ON Z.COD_SISTEMA = Q.COD_SISTEMA AND Z.COD_CLIENTE = Q.COD_CLIENTE AND Z.COD_CUENTA = Q.COD_CUENTA and z.TELEFONO is not null
INNER JOIN CORE_ESTADO_SERVICIO CES ON CES.COD_ESTADO = z.COD_ESTADO and CES.COD_ESTADO in (20, 22,23,24, 25)
where /*l.COD_LUNA not in (select cod_luna from LUNA_CONTROL)	and */moroso <> 993623 and moroso <> 988348 and moroso <> 1244113 and moroso <>1170435;

WITH t as
(
	SELECT Telef = CASE WHEN SUBSTRING(ltrim(rtrim(Descripcion)),1,1) in ('0','#') THEN RTRIM(SUBSTRING(ltrim(rtrim(Descripcion)),2,15)) ELSE ltrim(rtrim(Descripcion)) END, m.COD_LUNA, dm.TipoEstado 
	from DetalleMoroso dm 
	inner join Moroso m on m.Moroso = dm.Moroso
	WHERE COD_LUNA is not null and TipoEstado <> 7 and TipoDetalle = 1
)
merge t
using 
(
	select distinct COD_LUNA, TELEFONO from #source1
)s
on t.COD_LUNA = s.COD_LUNA and t.telef = s.telefono
WHEN MATCHED THEN UPDATE SET TipoEstado = 7;

---
drop table #source1
create table #source2(cod_luna int, telefono varchar(300),INDEX SourceCod NONCLUSTERED (cod_Luna ASC, telefono ASC))
insert #source2
select l.COD_LUNA, telefono
FROM Moroso L
INNER JOIN MASTER_CLIENTE CL ON L.COD_LUNA = CL.COD_LUNA --and COD_CLIENTE <>'100000000'
INNER JOIN CORE_SISTEMA S ON S.COD_SISTEMA = CL.COD_SISTEMA
INNER JOIN MASTER_CUENTA Q ON Q.COD_SISTEMA = CL.COD_SISTEMA AND Q.COD_CLIENTE = CL.COD_CLIENTE
INNER JOIN MASTER_SERVICIO Z ON Z.COD_SISTEMA = Q.COD_SISTEMA AND Z.COD_CLIENTE = Q.COD_CLIENTE AND Z.COD_CUENTA = Q.COD_CUENTA and z.TELEFONO is not null
INNER JOIN CORE_ESTADO_SERVICIO CES ON CES.COD_ESTADO = z.COD_ESTADO and CES.COD_ESTADO in (30)
where /*l.COD_LUNA not in (select cod_luna from LUNA_CONTROL)	and */moroso <> 993623 and moroso <> 988348 and moroso <> 1244113 and moroso <>1170435;

WITH t as
(
	SELECT Telef = CASE WHEN SUBSTRING(ltrim(rtrim(Descripcion)),1,1) in ('0','#') THEN RTRIM(SUBSTRING(ltrim(rtrim(Descripcion)),2,15)) ELSE ltrim(rtrim(Descripcion)) END, m.COD_LUNA, dm.TipoEstado 
	from DetalleMoroso dm 
	inner join Moroso m on m.Moroso = dm.Moroso
	WHERE COD_LUNA is not null and TipoEstado <>8 and TipoDetalle = 1 and TipoEstado <> 10 and TipoEstado <> 2
)
merge t
using 
(
	select distinct COD_LUNA, TELEFONO from #source2
)s
on t.COD_LUNA = s.COD_LUNA and t.telef = s.telefono
WHEN MATCHED THEN UPDATE SET TipoEstado = 8;

---
drop table #source2
create table #source3(cod_luna int, telefono varchar(300),INDEX SourceCod NONCLUSTERED (cod_Luna ASC, telefono ASC))
insert #source3
select l.COD_LUNA, telefono
FROM Moroso L
INNER JOIN MASTER_CLIENTE CL ON L.COD_LUNA = CL.COD_LUNA --and COD_CLIENTE <>'100000000'
INNER JOIN CORE_SISTEMA S ON S.COD_SISTEMA = CL.COD_SISTEMA
INNER JOIN MASTER_CUENTA Q ON Q.COD_SISTEMA = CL.COD_SISTEMA AND Q.COD_CLIENTE = CL.COD_CLIENTE
INNER JOIN MASTER_SERVICIO Z ON Z.COD_SISTEMA = Q.COD_SISTEMA AND Z.COD_CLIENTE = Q.COD_CLIENTE AND Z.COD_CUENTA = Q.COD_CUENTA and z.TELEFONO is not null
INNER JOIN CORE_ESTADO_SERVICIO CES ON CES.COD_ESTADO = z.COD_ESTADO and CES.COD_ESTADO in (10,21)
where /*l.COD_LUNA not in (select cod_luna from LUNA_CONTROL)	and */moroso <> 993623 and moroso <> 988348 and moroso <> 1244113 and moroso <>1170435;

WITH t as
(
	SELECT Telef = CASE WHEN SUBSTRING(ltrim(rtrim(Descripcion)),1,1) in ('0','#') THEN RTRIM(SUBSTRING(ltrim(rtrim(Descripcion)),2,15)) ELSE ltrim(rtrim(Descripcion)) END, m.COD_LUNA, dm.TipoEstado 
	from DetalleMoroso dm 
	inner join Moroso m on m.Moroso = dm.Moroso
	WHERE COD_LUNA is not null and TipoEstado not in (2,3,6) and TipoDetalle = 1
)
merge t
using 
(
	select distinct COD_LUNA, TELEFONO from #source3
)s
on t.COD_LUNA = s.COD_LUNA and t.telef = s.telefono
WHEN MATCHED THEN UPDATE SET TipoEstado = 6;

drop table #source3