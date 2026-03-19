# plot functions
extract_setsize_history <- function(df) {
  data_fitting <- df |>
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
  
  return(data_fitting)
}

plot_setsize_analysis <- function(df_setsize){
  df_setsize |>
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
    ggplot2::scale_x_continuous(breaks = 1:15) +
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

extract_error_history <- function(df, target_col) {
  df |>
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
    dplyr::filter(Is_Error == TRUE & Trial_Idx > 1)
}

# 绘图函数：计算均值与标准误，并输出 ggplot 图形
plot_error_analysis <- function(df_errors) {
  df_errors |>
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
      limits = c(0, 1.75), 
      breaks = seq(from = 0, to = 1.75, by = 0.25)
    ) +
    ggplot2::theme_classic() +
    ggplot2::labs(
      x = "Set Size",
      y = "Number of previous errors",
      color = "Error Type"
    )
}