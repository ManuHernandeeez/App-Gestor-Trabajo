using GestorTrabajoApi.Modelos;
using Microsoft.AspNetCore.Diagnostics;
using Npgsql;

namespace GestorTrabajoApi.Servicios;

// Convierte las excepciones en respuestas: GT001 en 409, GT002 en 404, GT003 en 403.
// Cualquier otra es un 500 sin detalles internos (el detalle queda solo en el registro del servidor).
public class ManejadorErrores : IExceptionHandler
{
    private readonly ILogger<ManejadorErrores> _log;

    public ManejadorErrores(ILogger<ManejadorErrores> log)
    {
        _log = log;
    }

    public async ValueTask<bool> TryHandleAsync(HttpContext contexto, Exception excepcion, CancellationToken cancelacion)
    {
        var (estado, error) = Traducir(excepcion);
        contexto.Response.StatusCode = estado;
        await contexto.Response.WriteAsJsonAsync(error, cancelacion);
        return true;
    }

    private (int Estado, ErrorRespuesta Error) Traducir(Exception excepcion)
    {
        if (excepcion is PostgresException postgres)
        {
            switch (postgres.SqlState)
            {
                case "GT001":
                    return (StatusCodes.Status409Conflict, new ErrorRespuesta(postgres.SqlState, postgres.MessageText));
                case "GT002":
                    return (StatusCodes.Status404NotFound, new ErrorRespuesta(postgres.SqlState, postgres.MessageText));
                case "GT003":
                    return (StatusCodes.Status403Forbidden, new ErrorRespuesta(postgres.SqlState, postgres.MessageText));
            }
        }

        _log.LogError(excepcion, "Error no controlado");
        return (StatusCodes.Status500InternalServerError,
            new ErrorRespuesta("ERROR_INTERNO", "Ocurrió un error inesperado. Intenta de nuevo más tarde"));
    }
}
