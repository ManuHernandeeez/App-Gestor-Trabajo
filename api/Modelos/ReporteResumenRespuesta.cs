namespace GestorTrabajoApi.Modelos;

// Totales de solicitudes por estado, calificaciones y cuentas.
public record ReporteResumenRespuesta(
    int TotalSolicitudes,
    int Publicadas,
    int Asignadas,
    int EnProceso,
    int Finalizadas,
    int Canceladas,
    int Vencidas,
    int TotalCalificaciones,
    decimal PromedioGeneral,
    int Clientes,
    int Trabajadores,
    int Suspendidos);
