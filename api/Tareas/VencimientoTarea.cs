using GestorTrabajoApi.Repositorios;
using Npgsql;

namespace GestorTrabajoApi.Tareas;

// Cada hora pasa a vencida toda solicitud publicada hace más de 72 horas sin asignar.
// Corre sin usuario, así que en la bitácora el cambio queda como tarea automática.
public class VencimientoTarea : BackgroundService
{
    private static readonly TimeSpan Intervalo = TimeSpan.FromHours(1);

    private readonly BaseDatos _bd;
    private readonly ILogger<VencimientoTarea> _log;

    public VencimientoTarea(BaseDatos bd, ILogger<VencimientoTarea> log)
    {
        _bd = bd;
        _log = log;
    }

    protected override async Task ExecuteAsync(CancellationToken cancelacion)
    {
        using var reloj = new PeriodicTimer(Intervalo);
        try
        {
            do
            {
                await VencerAsync();
            }
            while (await reloj.WaitForNextTickAsync(cancelacion));
        }
        catch (OperationCanceledException)
        {
            // la API se está apagando
        }
    }

    // Un error no detiene la tarea: se registra y se vuelve a intentar en la siguiente hora
    private async Task VencerAsync()
    {
        try
        {
            var vencidas = await _bd.EnTransaccionAsync(null, async conexion =>
            {
                await using var comando = new NpgsqlCommand("SELECT fn_vencer_solicitudes()", conexion);
                return (int)(await comando.ExecuteScalarAsync())!;
            });
            _log.LogInformation("Solicitudes vencidas: {Cantidad}", vencidas);
        }
        catch (Exception excepcion)
        {
            _log.LogError(excepcion, "No se pudieron vencer las solicitudes");
        }
    }
}
