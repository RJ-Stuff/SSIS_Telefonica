CREATE TABLE #TRAN_DEUDA(
	[COD_LUNA_DEUDA] [varchar](50) NOT NULL,
	[COD_LUNA] [int] NULL,
	[COD_SISTEMA] [tinyint] NULL,
	[COD_CLIENTE] [int] NULL,
	[COD_CUENTA] [varchar](10) NULL,
	[COD_SERVICIO] [varchar](12) NULL,
	[LETRA] [varchar](2) NULL,
	[CUOTA] [tinyint] NULL,
	[TIPO_DOCUMENTO] [smallint] NULL,
	[NRO_DOCUMENTO] [varchar](50) NULL,
	[COD_EMPRESA] [smallint] NULL,
	[COD_AGRUPACION] [tinyint] NULL,
	[FECHA_EMISION] [date] NULL,
	[FECHA_VENCIMIENTO] [date] NULL,
	[MONEDA] [money] NULL,
	[MONTO_FACTURADO] [money] NULL,
	[MONTO_AJUSTADO] [money] NULL,
	[MONTO_PAGADO] [money] NULL,
	[MONTO_RECLAMADO] [money] NULL,
	[MONTO_EXIGIBLE] [money] NULL--,
	--CONSTRAINT [PK_TRAN_DEUDA1] PRIMARY KEY CLUSTERED ([COD_LUNA_DEUDA] ASC)
) 

--PASO 2--> Copia TXT a tabla temporal. 

BULK INSERT #TRAN_DEUDA
FROM CONCAT ('D:\MUESTRA\TRAN_DEUDA_' , RIGHT('0' + RTRIM(DAY(GETDATE())), 2) , RIGHT('0' + RTRIM(MONTH(GETDATE())), 2) + '.txt')
WITH ( FIELDTERMINATOR = '|', ROWTERMINATOR = '\n' );
--PASO 3--> Compara tabla temporal con clientes asignados, elimina deudas que no nos pertenecen.

merge #tran_deuda t
using
(select * from master_luna where cod_agencia_avanzada =10 and retiro = 0 and cod_rango_deuda_avanzada >=5)s
on t.cod_luna = s.cod_luna
when not matched by source 
then delete;


----PASO 3.1

--delete from #TRAN_DEUDA where cod_cuenta is null
--select COD_LUNA_DEUDA,count(*) from #TRAN_DEUDA group by COD_LUNA_DEUDA having count(*)>1

--PASGO 4--> Compara tabla temporal con tabla de deudas, actualiza datos de deudas existentes, inserta deudas nuevas y marca deudas retiradas.

MERGE TRAN_DEUDA t
USING #TRAN_DEUDA s
ON t.COD_LUNA_DEUDA = s.COD_LUNA_DEUDA
WHEN MATCHED THEN
UPDATE SET t.MONTO_AJUSTADO = s.MONTO_AJUSTADO, t.MONTO_PAGADO = s.MONTO_PAGADO, t.MONTO_RECLAMADO = s.MONTO_RECLAMADO, t.MONTO_EXIGIBLE = s.MONTO_EXIGIBLE, t.FLAG_RETIRO = 0, t.FECHA_MODIFICACION = GETDATE()
--, t.COD_SISTEMA = s.COD_SISTEMA, t.COD_CLIENTE = s.COD_CLIENTE, t.COD_CUENTA = s.COD_CUENTA, t.COD_SERVICIO = s.COD_SERVICIO
WHEN NOT MATCHED BY TARGET and s.COD_CUENTA IS NOT NULL THEN 
INSERT(COD_LUNA_DEUDA, COD_LUNA, COD_SISTEMA, COD_CLIENTE, COD_CUENTA, COD_SERVICIO, LETRA, CUOTA, TIPO_DOCUMENTO, NRO_DOCUMENTO, COD_EMPRESA, COD_AGRUPACION, FECHA_EMISION,
	FECHA_VENCIMIENTO, MONEDA, MONTO_FACTURADO,  MONTO_AJUSTADO, MONTO_PAGADO, MONTO_RECLAMADO, MONTO_EXIGIBLE, FECHA_INGRESO)
VALUES(s.COD_LUNA_DEUDA, s.COD_LUNA, s.COD_SISTEMA, s.COD_CLIENTE, COD_CUENTA, s.COD_SERVICIO, s.LETRA, s.CUOTA, s.TIPO_DOCUMENTO, s.NRO_DOCUMENTO, s.COD_EMPRESA, s.COD_AGRUPACION, s.FECHA_EMISION,
	s.FECHA_VENCIMIENTO, s.MONEDA, s.MONTO_FACTURADO, s.MONTO_AJUSTADO, s.MONTO_PAGADO, s.MONTO_RECLAMADO, s.MONTO_EXIGIBLE, GETDATE())
WHEN NOT MATCHED BY SOURCE AND t.FLAG_RETIRO = 0 THEN
UPDATE	SET t.FLAG_RETIRO = 1, t.FECHA_RETIRO = getdate();

--PASO 5--> Elimina tabla temporal

DROP TABLE #TRAN_DEUDA;

--PASO 6 -->Calcular montos totales por cliente

WITH t as
(
SELECT * FROM LUNA_CONTROL WHERE Periodo = '201604'
)
MERGE t
USING
(
	SELECT d.COD_LUNA, Exigible = SUM(MONTO_EXIGIBLE), Facturado = SUM(MONTO_FACTURADO)
	FROM TRAN_DEUDA d
	INNER JOIN MASTER_LUNA c on c.COD_LUNA = d.COD_LUNA AND c.COD_RANGO_DEUDA_AVANZADA>=5 AND c.COD_AGENCIA_AVANZADA = 10 and Retiro = 0
	INNER JOIN MASTER_CUENTA m on m.COD_SISTEMA = d.COD_SISTEMA and m.COD_CLIENTE = d.COD_CLIENTE and m.COD_CUENTA = d.COD_CUENTA --and IND_INTOCABLE is NULL
	LEFT JOIN MASTER_CUENTA_INDICADORES i on m.COD_SISTEMA = i.COD_SISTEMA and m.COD_CLIENTE = i.COD_CLIENTE and m.COD_CUENTA = i.COD_CUENTA and i.COD_INDICADOR = 8
	WHERE FECHA_VENCIMIENTO < CONVERT(DATE,GETDATE()) AND FLAG_RETIRO = 0 and i.COD_CUENTA is null
	GROUP BY d.COD_LUNA
)s
ON t.COD_LUNA = s.COD_LUNA
WHEN MATCHED THEN
UPDATE SET t.Exigible = s.Exigible, t.Facturado = s.Facturado, t.Retiro = 0
WHEN NOT MATCHED BY SOURCE and t.Retiro = 0 THEN
UPDATE SET t.Retiro = 1, t.FechaRetiro = getdate();

--PASO 7 -->Calcular primera fecha de vencimiento por cliente

WITH t as
(
SELECT * FROM LUNA_CONTROL WHERE Periodo = '201604'
)
MERGE t
USING
(
	SELECT * FROM (
	SELECT d.COD_LUNA, FECHA_VENCIMIENTO, CUENTA = ROW_NUMBER() over (partition by d.COD_LUNA order by FECHA_VENCIMIENTO)
	FROM TRAN_DEUDA d
	INNER JOIN MASTER_LUNA c on c.COD_LUNA = d.COD_LUNA AND c.COD_RANGO_DEUDA_AVANZADA >= 5 AND c.COD_AGENCIA_AVANZADA = 10 and Retiro = 0
	INNER JOIN MASTER_CUENTA m on m.COD_SISTEMA = d.COD_SISTEMA and m.COD_CLIENTE = d.COD_CLIENTE and m.COD_CUENTA = d.COD_CUENTA --and IND_INTOCABLE is NULL
	LEFT JOIN MASTER_CUENTA_INDICADORES i on m.COD_SISTEMA = i.COD_SISTEMA and m.COD_CLIENTE = i.COD_CLIENTE and m.COD_CUENTA = i.COD_CUENTA and i.COD_INDICADOR = 8
	WHERE FECHA_VENCIMIENTO < CONVERT(DATE,GETDATE()) AND FLAG_RETIRO = 0 and i.COD_CUENTA is null)a
	WHERE CUENTA = 1
)s
ON t.COD_LUNA = s.COD_LUNA
WHEN MATCHED THEN
UPDATE SET t.PrimeraFechaVencimiento = FECHA_VENCIMIENTO;

--PASO 8 -->Calcular montos totales por servicio

MERGE MASTER_SERVICIO t
USING
(
	SELECT COD_SISTEMA, COD_CUENTA, COD_CLIENTE/*, COD_SERVICIO*/, Exigible = SUM(MONTO_EXIGIBLE), Facturado = SUM(MONTO_FACTURADO)
	FROM TRAN_DEUDA d
	INNER JOIN MASTER_LUNA c on c.COD_LUNA = d.COD_LUNA AND c.COD_RANGO_DEUDA_AVANZADA >=5 AND c.COD_AGENCIA_AVANZADA = 10 and Retiro = 0
	WHERE FECHA_VENCIMIENTO < CONVERT(DATE,GETDATE()) AND FLAG_RETIRO = 0 /*AND COD_SISTEMA in (2,3)*/
	GROUP BY COD_SISTEMA, COD_CUENTA, COD_CLIENTE--, COD_SERVICIO
)s
ON t.COD_SISTEMA = s.COD_SISTEMA and s.COD_CUENTA = t.COD_CUENTA and s.COD_CLIENTE = t.COD_CLIENTE --and s.COD_SERVICIO = t.COD_SERVICIO
WHEN MATCHED /*AND (t.Exigible <> s.Exigible OR t.Facturado <> s.Facturado or t.Activo = 0)*/ THEN
UPDATE SET t.Exigible = s.Exigible , t.Facturado = s.Facturado, t.activo = 1
WHEN NOT MATCHED BY SOURCE AND t.Activo = 1 THEN
UPDATE SET t.Activo = 0, Facturado = NULL, Exigible = NULL, PrimeraFechaVencimiento = NULL, NumeroRecibos = NULL;

--PASO 9 -->Calcular primera fecha de vencimiento y n�mero de recibos por servicio

MERGE MASTER_SERVICIO t
USING
(
	SELECT * FROM (
	SELECT COD_SISTEMA, COD_CUENTA, COD_CLIENTE, /*COD_SERVICIO,*/ FECHA_VENCIMIENTO, FILA = ROW_NUMBER() over (partition by COD_SISTEMA, COD_CUENTA, COD_CLIENTE/*, COD_SERVICIO*/ order by FECHA_VENCIMIENTO),
		CUENTA = dense_rank() over (partition by COD_SISTEMA, COD_CUENTA, COD_CLIENTE/*, COD_SERVICIO*/ order by FECHA_VENCIMIENTO DESC)
	FROM TRAN_DEUDA d
	INNER JOIN MASTER_LUNA c on c.COD_LUNA = d.COD_LUNA AND c.COD_RANGO_DEUDA_AVANZADA >= 5 AND c.COD_AGENCIA_AVANZADA  = 10 and Retiro = 0
	WHERE FECHA_VENCIMIENTO < CONVERT(DATE,GETDATE()) AND FLAG_RETIRO = 0 /*AND COD_SISTEMA in (2,3)*/)a
	WHERE FILA = 1
)s
ON t.COD_SISTEMA = s.COD_SISTEMA and s.COD_CUENTA = t.COD_CUENTA and s.COD_CLIENTE = t.COD_CLIENTE --and s.COD_SERVICIO = t.COD_SERVICIO
WHEN MATCHED THEN
UPDATE SET t.PrimeraFechaVencimiento = s.FECHA_VENCIMIENTO, t.NumeroRecibos = s.CUENTA;





DROP TABLE LUNA_RESUMEN


--Actualizaci�n de Luna Resumen
CREATE TABLE LUNA_RESUMEN(
	COD_LUNA int NOT NULL, 
	EXIGIBLE decimal(18,2) NOT NULL,
	SALDO decimal (18,2) NOT NULL,
	PAGO decimal(18,2) NOT NULL,
	CONSTRAINT [PK_LUNA_RESUMEN] PRIMARY KEY CLUSTERED ([COD_LUNA] ASC)
)

INSERT LUNA_RESUMEN
select COD_LUNA, EXIGIBLE = ISNULL(EXIGIBLE, 0) + ISNULL(PAGO, 0), SALDO = ISNULL(EXIGIBLE, 0), PAGO = ISNULL(PAGO, 0) 
from(
	select l.COD_LUNA, FLAG_RETIRO = CASE WHEN d.FLAG_RETIRO = 0 THEN 'EXIGIBLE' ELSE 'PAGO' END, MONTO_EXIGIBLE = sum(monto_exigible) 
	from MASTER_LUNA l
	inner join
	(
		select * from tran_deuda where FECHA_MODIFICACION >= '20170601' and FECHA_VENCIMIENTO <CAST(getdate() as date)
		union
		select * from tran_deuda where FECHA_INGRESO >= '20170601' and FECHA_VENCIMIENTO <CAST(getdate() as date)
	)d on l.COD_LUNA = d.COD_LUNA
	where l.COD_RANGO_DEUDA_AVANZADA >= 5 and l.COD_AGENCIA_AVANZADA = 10 and retiro = 0
	group by l.COD_LUNA, d.FLAG_RETIRO) as S
PIVOT
(SUM(MONTO_EXIGIBLE)
FOR [FLAG_RETIRO] in ([EXIGIBLE],[PAGO])
) as piv


--Actualizar deuda avanzada

CREATE TABLE #temporal
(
COD_LUNA int,
TEMPRANA money,
AVANZADA money,
PORVENCER money,
TASA money,
CONSTRAINT [PK_TEMPORAL9] PRIMARY KEY CLUSTERED ([COD_LUNA] ASC)
)

INSERT #temporal
select cod_luna, 
TEMPRANA = SUM(CASE WHEN DATEDIFF(DAY,FECHA_VENCIMIENTO, '2017-06-01') > 0 AND DATEDIFF(DAY,FECHA_VENCIMIENTO, '2017-06-01') < 91 THEN MONTO_EXIGIBLE ELSE 0 END),
AVANZADA = SUM(CASE WHEN DATEDIFF(DAY,FECHA_VENCIMIENTO, '2017-06-01') > 90 AND DATEDIFF(DAY,FECHA_VENCIMIENTO, '2017-06-01') <180 THEN MONTO_EXIGIBLE ELSE 0 END),
PORVENCER = SUM(CASE WHEN DATEDIFF(DAY,FECHA_VENCIMIENTO, '2017-06-01') < 1 AND FECHA_VENCIMIENTO < CONVERT(DATE,GETDATE()) THEN MONTO_EXIGIBLE ELSE 0 END),
TASA = SUM(CASE WHEN DATEDIFF(DAY,FECHA_VENCIMIENTO, '2017-06-01') > 179 THEN MONTO_EXIGIBLE ELSE 0 END)
from TRAN_DEUDA D
LEFT JOIN MASTER_CUENTA_INDICADORES i on d.COD_SISTEMA = i.COD_SISTEMA and d.COD_CLIENTE = i.COD_CLIENTE and d.COD_CUENTA = i.COD_CUENTA and i.COD_INDICADOR = 8
WHERE FLAG_RETIRO = 0 and i.COD_CLIENTE is NULL
--WHERE COD_LUNA_DEUDA NOT IN(
--select COD_LUNA_DEUDA 
--from tran_deuda d
--LEFT join master_cuenta q on d.cod_sistema = q.cod_sistema and d.cod_cliente = q.cod_cliente and d.cod_cuenta = q.cod_cuenta
--where q.cod_sistema is null)
group by cod_luna;


WITH t as
(
SELECT COD_LUNA, Temprana, Avanzada, PorVencer, Tasa, Exigible 
FROM LUNA_CONTROL
WHERE PERIODO = '201604' and retiro = 0
)
MERGE t
USING #Temporal s
ON t.COD_LUNA = s.COD_LUNA
WHEN MATCHED THEN
UPDATE SET
	t.Temprana = s.Temprana,
	t.Avanzada = s.Avanzada,
	t.PorVencer = s.PorVencer,
	t.Tasa = s.Tasa
WHEN NOT MATCHED BY SOURCE THEN
UPDATE SET
	t.Temprana = 0,
	t.Avanzada = 0,
	t.PorVencer = 0;

drop table #temporal