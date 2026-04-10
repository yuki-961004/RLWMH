# plot functions
plot_setsize_analysis <- function(df) {
  data_fitting <- df |>
    dplyr::filter(Stim_Count <= 9) |>
    dplyr::select(
      Subject, SetSize, Stim_Count, Reward
    ) |>
    dplyr::group_by(Subject, SetSize, Stim_Count) |>
    dplyr::summarise(Acc = mean(Reward)) |>
    dplyr::ungroup()
  
  # 计算每个 SetSize 在每个 Stim_Count 下的均值和标准误
  data_fitting <- stats::aggregate(
    Acc ~ Stim_Count + SetSize,
    data = data_fitting,
    FUN = function(x) {
      c(mean = base::mean(x), se = stats::sd(x) / base::sqrt(base::length(x)))
    }
  )
  
  # 将 aggregate 的 matrix 结果展开为列
  data_fitting <- base::do.call(base::data.frame, data_fitting)
  base::colnames(data_fitting) <- c("Stim_Count", "SetSize", "Acc", "SE")
  
  data_fitting |>
    ggplot2::ggplot(
      mapping = ggplot2::aes(
        x = Stim_Count,
        y = Acc,
        color = base::as.factor(SetSize),
        group = SetSize
      )
    ) +
    ggplot2::geom_line(linewidth = 0.8) +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_x_continuous(breaks = 1:9) +
    ggplot2::scale_y_continuous(limits = c(0, 1)) +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = Acc - SE, ymax = Acc + SE),
      width = 0.2
    ) +
    ggplot2::labs(
      x = "Iteration (Stim_Count)",
      y = "Accuracy (Acc)",
      color = "Set Size"
    ) +
    papaja::theme_apa()
}

plot_error_analysis <- function(df, target_col) {
  df |>
    dplyr::filter(Stim_Count <= 9) |>
    dplyr::mutate(
      Target_Act = .data[[target_col]],
      Stimulus = base::substr(Target_Act, 1, 1),
      Correct_Act = dplyr::case_when(
        Reward_1 == 1 ~ Object_1,
        Reward_2 == 1 ~ Object_2,
        Reward_3 == 1 ~ Object_3
      ),
      Is_Error = Target_Act != Correct_Act,
      Unchosen_Error = dplyr::case_when(
        !Is_Error ~ NA_character_,
        Target_Act == Object_1 & Correct_Act == Object_2 ~ Object_3,
        Target_Act == Object_1 & Correct_Act == Object_3 ~ Object_2,
        Target_Act == Object_2 & Correct_Act == Object_1 ~ Object_3,
        Target_Act == Object_2 & Correct_Act == Object_3 ~ Object_1,
        Target_Act == Object_3 & Correct_Act == Object_1 ~ Object_2,
        Target_Act == Object_3 & Correct_Act == Object_2 ~ Object_1
      )
    ) |>
    dplyr::group_by(Subject, Block, Stimulus) |>
    dplyr::mutate(
      Trial_Idx = dplyr::row_number(),
      Chosen_Prev = purrr::map_int(Trial_Idx, function(i) {
        if (i == 1) {
          0
        } else {
          base::sum(Target_Act[1:(i - 1)] == Target_Act[i])
        }
      }),
      Unchosen_Prev = purrr::map_int(Trial_Idx, function(i) {
        if (i == 1) {
          0
        } else {
          base::sum(Target_Act[1:(i - 1)] == Unchosen_Error[i])
        }
      })
    ) |>
    dplyr::ungroup() |>
    # 核心修改：只保留错误试次，且剔除第一次遇到该刺激时的瞎猜
    dplyr::filter(Is_Error == TRUE & Trial_Idx > 1)  |>
    dplyr::group_by(SetSize) |>
    dplyr::summarise(
      Chosen_Mean = base::mean(Chosen_Prev, na.rm = TRUE),
      Chosen_SE = stats::sd(Chosen_Prev, na.rm = TRUE) / 
        base::sqrt(dplyr::n()),
      Unchosen_Mean = base::mean(Unchosen_Prev, na.rm = TRUE),
      Unchosen_SE = stats::sd(Unchosen_Prev, na.rm = TRUE) / 
        base::sqrt(dplyr::n()),
      .groups = "drop"
    ) |>
    tidyr::pivot_longer(
      cols = c(Chosen_Mean, Unchosen_Mean),
      names_to = "Error_Type",
      values_to = "Mean_Errors"
    ) |>
    dplyr::mutate(
      SE = dplyr::if_else(
        Error_Type == "Chosen_Mean", 
        Chosen_SE, 
        Unchosen_SE
      )
    ) |>
    ggplot2::ggplot(
      ggplot2::aes(
        x = SetSize, 
        y = Mean_Errors, 
        color = Error_Type
      )
    ) +
    ggplot2::geom_line() +
    ggplot2::geom_point() +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = Mean_Errors - SE, ymax = Mean_Errors + SE),
      width = 0.2
    ) +
    ggplot2::scale_y_continuous(
      limits = c(0, 2), 
      breaks = seq(from = 0, to = 2, by = 0.25)
    ) +
    ggplot2::theme_classic() +
    ggplot2::labs(
      x = "Set Size",
      y = "Number of previous errors",
      color = "Error Type"
    )
}

plot_avoid_error <- function(df) {
  df |>
    dplyr::group_by(Subject, Block, Object_1) |>
    dplyr::arrange(Trial, .by_group = TRUE) |>
    dplyr::mutate(
      Correct_Action = dplyr::case_when(
        Reward_1 == 1 ~ Object_1,
        Reward_2 == 1 ~ Object_2,
        Reward_3 == 1 ~ Object_3
      ),
      Is_Error = dplyr::if_else(Action != Correct_Action, 1, 0),
      Unchosen_Error = dplyr::case_when(
        Is_Error == 0 ~ NA_character_,
        Object_1 != Correct_Action & Object_1 != Action ~ Object_1,
        Object_2 != Correct_Action & Object_2 != Action ~ Object_2,
        Object_3 != Correct_Action & Object_3 != Action ~ Object_3
      ),
      Prev_Chosen = purrr::map_int(
        seq_along(Action),
        ~ sum(Action[seq_len(.x - 1)] == Action[.x])
      ),
      Prev_Unchosen = purrr::map_int(
        seq_along(Action),
        ~ sum(Action[seq_len(.x - 1)] == Unchosen_Error[.x])
      )
    ) |>
    dplyr::ungroup() |>
    # 核心修正: 仅保留错误试次，且必须已有历史错误记录
    dplyr::filter(Is_Error == 1 & (Prev_Chosen + Prev_Unchosen) > 0) |>
    dplyr::mutate(
      Stage = dplyr::if_else(Stim_Count <= 5, "Early", "Late"),
      # 核心修正: 差值方向为 未选 - 已选
      Diff = Prev_Unchosen - Prev_Chosen
    ) |>
    dplyr::group_by(Subject, SetSize, Stage) |>
    dplyr::summarise(
      Subj_Mean_Diff = mean(Diff, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::group_by(SetSize, Stage) |>
    dplyr::summarise(
      SE = sd(Subj_Mean_Diff, na.rm = TRUE) / sqrt(dplyr::n()),
      Mean_Diff = mean(Subj_Mean_Diff, na.rm = TRUE),
      .groups = "drop"
    ) |>
    ggplot2::ggplot(
      mapping = ggplot2::aes(
        x = as.factor(SetSize),
        y = Mean_Diff,
        color = Stage,
        group = Stage
      )
    ) +
    ggplot2::geom_line(linewidth = 0.8) +
    ggplot2::geom_errorbar(
      mapping = ggplot2::aes(
        ymin = Mean_Diff - SE,
        ymax = Mean_Diff + SE
      ),
      width = 0.2,
      linewidth = 0.6
    ) +
    ggplot2::scale_color_manual(
      values = c("Early" = "#000000", "Late" = "#808080")
    ) +
    ggplot2::labs(
      title = "Avoid error",
      x = "Set size",
      y = "Difference"
    ) +
    papaja::theme_apa() +
    ggplot2::theme(
      text = ggplot2::element_text(size = 14),
      legend.position = c(0.8, 0.8),
      legend.title = ggplot2::element_blank()
    ) +
    ggplot2::coord_cartesian(ylim = c(-0.5, 1.0))
}